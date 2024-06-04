// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {
    struct Poll {
        string title;
        uint256 endTime;
        uint256 reward;
        uint256 joinFee;
        address creator;
        mapping(address => bool) participants;
        mapping(address => bool) hasVoted;
        mapping(uint256 => uint256) votes;
        uint256 totalVotes;
        string[] options;
        bool isOpen;
        address[] winners;
    }

    mapping(uint256 => Poll) public polls;
    uint256 public pollCount;

    event PollCreated(uint256 pollId, string title, uint256 endTime, uint256 reward, uint256 joinFee, string[] options, address creator);
    event PollJoined(uint256 pollId, address participant);
    event PollVoted(uint256 pollId, address voter, uint256 optionId);
    event PollClosed(uint256 pollId, address[] winners);

    function createPoll(
        string memory _title,
        uint256 _endTime,
        uint256 _reward,
        uint256 _joinFee,
        string[] memory _options
    ) external payable {
        require(msg.value >= _reward + 0.5 ether, "Insufficient payment for creating poll");

        // Check for duplicate options
        for (uint256 i = 0; i < _options.length; i++) {
            for (uint256 j = i + 1; j < _options.length; j++) {
                require(
                    keccak256(abi.encodePacked(_options[i])) != keccak256(abi.encodePacked(_options[j])),
                    "Duplicate options not allowed"
                );
            }
        }

        uint256 pollId = pollCount++;
        Poll storage poll = polls[pollId];
        poll.title = _title;
        poll.endTime = _endTime;
        poll.reward = _reward;
        poll.creator = msg.sender;
        poll.options = _options;
        poll.isOpen = true;
        poll.joinFee = _joinFee;

        emit PollCreated(pollId, _title, _endTime, _reward, _joinFee, _options, msg.sender);
    }

    function joinPoll(uint256 _pollId) external payable {
        Poll storage poll = polls[_pollId];
        require(poll.isOpen, "Poll is closed");
        require(!poll.participants[msg.sender], "Already joined");
        require(msg.value >= poll.joinFee, "Insufficient payment for joining poll");

        // Check if the participant's address is already an option
        for (uint256 i = 0; i < poll.options.length; i++) {
            require(
                keccak256(abi.encodePacked(poll.options[i])) != keccak256(abi.encodePacked(toAsciiString(msg.sender))),
                "Address already an option"
            );
        }

        address creator = poll.creator;

        // Transfer the payment to the creator
        payable(creator).transfer(msg.value);

        // Mark the participant as joined
        poll.participants[msg.sender] = true;

        // Add the participant's address as a new option
        poll.options.push(toAsciiString(msg.sender));

        emit PollJoined(_pollId, msg.sender);
    }

    function vote(uint256 _pollId, uint256 _optionId) external {
        Poll storage poll = polls[_pollId];
        require(poll.isOpen, "Poll is closed");
        require(!poll.hasVoted[msg.sender], "Already voted");
        require(_optionId < poll.options.length, "Invalid option");

        // Check if the voter is already an option
        for (uint256 i = 0; i < poll.options.length; i++) {
            require(
                keccak256(abi.encodePacked(poll.options[i])) != keccak256(abi.encodePacked(toAsciiString(msg.sender))),
                "Voter is an option in this poll"
            );
        }

        poll.votes[_optionId]++;
        poll.totalVotes++;
        poll.hasVoted[msg.sender] = true;

        emit PollVoted(_pollId, msg.sender, _optionId);
    }

    function closePoll(uint256 _pollId) public {
        Poll storage poll = polls[_pollId];
        require(block.timestamp >= poll.endTime, "Poll is still open");

        poll.isOpen = false;

        uint256 maxVotes = 0;
        for (uint256 i = 0; i < poll.options.length; i++) {
            if (poll.votes[i] > maxVotes) {
                maxVotes = poll.votes[i];
            }
        }

        // Check if all options have zero votes
        bool allZeroVotes = true;
        for (uint256 i = 0; i < poll.options.length; i++) {
            if (poll.votes[i] > 0) {
                allZeroVotes = false;
                break;
            }
        }

        if (allZeroVotes) {
            // Return reward to the creator
            payable(poll.creator).transfer(poll.reward);
        } else {
            for (uint256 i = 0; i < poll.options.length; i++) {
                if (poll.votes[i] == maxVotes) {
                    poll.winners.push(parseAddr(poll.options[i]));
                }
            }

            if (poll.winners.length > 0) {
                uint256 rewardPerWinner = poll.reward / poll.winners.length;
                for (uint256 i = 0; i < poll.winners.length; i++) {
                    payable(poll.winners[i]).transfer(rewardPerWinner);
                }
            }
        }

        emit PollClosed(_pollId, poll.winners);
    }

    function getOptions(uint256 _pollId) external view returns (string[] memory) {
        return polls[_pollId].options;
    }

    function getVotes(uint256 _pollId, uint256 _optionId) external view returns (uint256) {
        return polls[_pollId].votes[_optionId];
    }

    function getWinners(uint256 _pollId) external view returns (address[] memory) {
        return polls[_pollId].winners;
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function parseAddr(string memory _a) internal pure returns (address) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 0; i < 40; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) b1 -= 87;
            else if ((b1 >= 48) && (b1 <= 57)) b1 -= 48;
            if ((b2 >= 97) && (b2 <= 102)) b2 -= 87;
            else if ((b2 >= 48) && (b2 <= 57)) b2 -= 48;
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}