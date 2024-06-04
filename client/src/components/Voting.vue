<template>
  <div class="container">
    <h1>Create Poll</h1>
    <form @submit.prevent="createPoll">
      <div class="form-group">
        <input v-model="title" class="form-control" placeholder="Poll Title" required />
      </div>
      <div class="form-group">
        <input v-model="endTime" class="form-control" type="datetime-local" required />
      </div>
      <div class="form-group">
        <input v-model="reward" class="form-control" type="number" step="0.01" placeholder="Reward (ETH)" required />
      </div>
      <div class="form-group">
        <input v-model="joinFee" class="form-control" type="number" step="0.01" placeholder="Join Fee (ETH)" required />
      </div>
      <div class="form-group">
        <input v-model="options" class="form-control" placeholder="Options (comma separated)" required />
      </div>
      <button type="submit" class="btn-create">Create Poll</button>
    </form>

    <h1>All Polls</h1>
    <div v-for="(poll, index) in polls" :key="index" class="card">
      <div class="card-body">
        <h3>
          {{ poll.title }}
          <span v-if="hasEnded(poll.endTime)" class="badge badge-secondary">已结束</span>
        </h3>
        <p>Created by: {{ poll.creator }}</p>
        <p>End Time: {{ formatEndTime(poll.endTime) }}</p>
        <p>Reward: {{ web3.utils.fromWei(String(poll.reward), 'ether') }} ETH</p>
        <p>Join Fee: {{ web3.utils.fromWei(String(poll.joinFee), 'ether') }} ETH</p>
        <div v-if="poll.options && poll.options.length > 0">
          <p>Options:</p>
          <div v-for="(option, optionIndex) in poll.options" :key="optionIndex">
            <button @click="vote(poll.pollId, optionIndex)" :disabled="hasEnded(poll.endTime)" class="btn-option">
              {{ option }} ({{ poll.votes[optionIndex] }} votes)
            </button>
          </div>
        </div>
        <button @click="joinPoll(index)" :disabled="hasEnded(poll.endTime)" class="btn-join mt-2">Join Poll</button>
        <div v-if="!hasEnded(poll.endTime)">
          <p>Current Winning Options:</p>
          <ul>
            <li v-for="(winner, index) in getCurrentWinners(poll)" :key="index">
              {{ winner }}
            </li>
            <li v-if="getCurrentWinners(poll).length === 0">none</li>
          </ul>
        </div>
        <div v-else>
          <p>Final Winning Options:</p>
          <ul>
            <li v-for="(winner, index) in poll.winners" :key="index">
              {{ winner }}
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Web3 from 'web3';
import VotingContract from '../contracts/Voting.json';

export default {
  name: 'VotingSystem',
  data() {
    return {
      web3: null,
      accounts: [],
      contract: null,
      title: '',
      endTime: '',
      reward: 0,
      joinFee: 0,
      options: '',
      polls: []
    };
  },
  async created() {
    try {
      await this.initWeb3();
      await this.initContract();
      await this.loadAccounts();
      await this.loadPolls();
      this.startPollCheckInterval();
      this.listenToPollClosedEvent();
    } catch (error) {
      console.error('Error in created lifecycle hook:', error);
    }
  },
  methods: {
    async initWeb3() {
      if (window.ethereum) {
        this.web3 = new Web3(window.ethereum);
        await window.ethereum.enable();
      } else if (window.web3) {
        this.web3 = new Web3(window.web3.currentProvider);
      } else {
        alert('Please use a web3-enabled browser');
      }
    },
    async initContract() {
      try {
        const networkId = await this.web3.eth.net.getId();
        const deployedNetwork = VotingContract.networks[networkId];
        if (deployedNetwork) {
          this.contract = new this.web3.eth.Contract(
            VotingContract.abi,
            deployedNetwork.address,
          );
        } else {
          alert('Contract not deployed on this network');
        }
      } catch (error) {
        console.error('Error initializing contract:', error);
      }
    },
    async loadAccounts() {
      try {
        this.accounts = await this.web3.eth.getAccounts();
      } catch (error) {
        console.error('Error loading accounts:', error);
      }
    },
    async createPoll() {
      try {
        let optionsArray = this.options.split(',').map(opt => opt.trim().toLowerCase());
        const endTimeUnix = Math.floor(new Date(this.endTime).getTime() / 1000);
        const rewardInWei = this.web3.utils.toWei(this.reward.toString(), 'ether');
        const joinFeeInWei = this.web3.utils.toWei(this.joinFee.toString(), 'ether');

        if (isNaN(parseFloat(this.reward)) || isNaN(parseFloat(this.joinFee))) {
          alert('Invalid reward or join fee');
          return;
        }

        optionsArray = [...new Set(optionsArray)];

        const totalPaymentInEth = parseFloat(this.reward) + 0.5;
        const totalPayment = this.web3.utils.toWei(totalPaymentInEth.toString(), 'ether');

        await this.contract.methods.createPoll(this.title, endTimeUnix, rewardInWei, joinFeeInWei, optionsArray)
          .send({ from: this.accounts[0], value: totalPayment });

        alert('Poll created successfully');
        this.title = '';
        this.endTime = '';
        this.reward = 0;
        this.joinFee = 0;
        this.options = '';
        await this.loadPolls();
      } catch (error) {
        console.error('Error creating poll:', error);
      }
    },
    async joinPoll(pollId) {
      try {
        const poll = this.polls[pollId];
        const participantAddress = this.web3.utils.toChecksumAddress(this.accounts[0]);
        const participantAsOption = this.web3.utils.toChecksumAddress(participantAddress.toLowerCase());
        for (let i = 0; i < poll.options.length; i++) {
          if (poll.options[i].toLowerCase() === participantAsOption) {
            alert('Your address is already an option in this poll');
            return;
          }
        }
        await this.contract.methods.joinPoll(pollId).send({ from: this.accounts[0], value: poll.joinFee });
        alert('Joined poll successfully');
        await this.loadPolls();
      } catch (error) {
        console.error('Error joining poll:', error);
      }
    },
    async vote(pollId, optionId) {
      try {
        await this.contract.methods.vote(pollId, optionId).send({ from: this.accounts[0] });
        alert('Voted successfully');
        await this.loadPolls();
      } catch (error) {
        console.error('Error voting:', error);
      }
    },
    async closePoll(pollId) {
      try {
        if (this.contract) {
          await this.contract.methods.closePoll(pollId).send({ from: this.accounts[0] });

          alert('Poll closed successfully');
          await this.loadPolls();
        } else {
          alert('Contract is not initialized');
        }
      } catch (error) {
        console.error('Error closing poll:', error);
      }
    },
    async loadPolls() {
      try {
        const pollCount = await this.contract.methods.pollCount().call();
        const polls = [];
        for (let i = 0; i < pollCount; i++) {
          const poll = await this.contract.methods.polls(i).call();
          const options = await this.contract.methods.getOptions(i).call();
          const votes = await Promise.all(options.map((_, index) => this.contract.methods.getVotes(i, index).call()));
          const winners = await this.contract.methods.getWinners(i).call();
          polls.push({ ...poll, pollId: i, options, votes, winners });
        }
        this.polls = polls;
      } catch (error) {
        console.error('Error loading polls:', error);
      }
    },
    getCurrentWinners(poll) {
      const maxVotes = Math.max(...poll.votes.map(vote => Number(vote)));
      const allZeroVotes = poll.votes.every(vote => Number(vote) === 0);

      if (allZeroVotes) {
        return [];
      }

      return poll.options.filter((option, index) => Number(poll.votes[index]) === maxVotes);
    },
    hasEnded(endTime) {
      return new Date().getTime() / 1000 > Number(endTime);
    },
    startPollCheckInterval() {
      setInterval(async () => {
        for (let poll of this.polls) {
          if (this.hasEnded(poll.endTime) && poll.isOpen) {
            await this.closePoll(poll.pollId);
          }
        }
      }, 10000);
    },
    listenToPollClosedEvent() {
      this.contract.events.PollClosed()
        .on('data', async event => {
          const { pollId, winners } = event.returnValues;
          console.log(`PollClosed event received: pollId = ${pollId}, winners = ${winners}`);
          await this.loadPolls();
        })
        .on('error', error => {
          console.error('Error receiving PollClosed event:', error);
        });
    },
    formatEndTime(endTime) {
      return new Date(Number(endTime) * 1000).toLocaleString();
    }
  },
};
</script>

<style scoped>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  background: #f7f7f7;
  border-radius: 10px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

h1 {
  color: #333;
  text-align: center;
  margin-bottom: 20px;
  font-family: 'Arial', sans-serif;
}

.form-group {
  margin-bottom: 15px;
}

.form-control {
  padding: 10px;
  border-radius: 5px;
  border: 1px solid #ddd;
  width: 100%;
  transition: border-color 0.3s;
}

.form-control:focus {
  border-color: #007bff;
}

.btn-create {
  margin-top: 5px;
  padding: 10px 20px;
  border-radius: 5px;
  border: none;
  color: #fff;
  background: linear-gradient(45deg, #28a745, #218838);
  cursor: pointer;
  transition: background 0.3s, transform 0.3s;
}

.btn-create:hover {
  background: linear-gradient(45deg, #218838, #1e7e34);
  transform: translateY(-2px);
}

.btn-join {
  margin-top: 5px;
  padding: 10px 20px;
  border-radius: 5px;
  border: none;
  color: #fff;
  background: linear-gradient(45deg, #ffc107, #e0a800);
  cursor: pointer;
  transition: background 0.3s, transform 0.3s;
}

.btn-join:hover {
  background: linear-gradient(45deg, #e0a800, #c69500);
  transform: translateY(-2px);
}

.btn-option {
  margin-top: 5px;
  padding: 10px 20px;
  border-radius: 5px;
  border: none;
  color: #fff;
  background: linear-gradient(45deg, #17a2b8, #138496);
  cursor: pointer;
  transition: background 0.3s, transform 0.3s;
}

.btn-option:hover {
  background: linear-gradient(45deg, #138496, #117a8b);
  transform: translateY(-2px);
}

.card {
  padding: 20px;
  border: 1px solid #ddd;
  border-radius: 10px;
  margin-bottom: 20px;
  background: #fff;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  transition: transform 0.3s, box-shadow 0.3s;
}

.card:hover {
  transform: translateY(-5px);
  box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
}

.card-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.badge-secondary {
  background: #6c757d;
  color: #fff;
  border-radius: 5px;
  padding: 5px 10px;
}

button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

ul {
  padding-left: 20px;
}

li {
  list-style-type: disc;
}

.alert {
  padding: 10px;
  background: #ffeb3b;
  color: #333;
  border-radius: 5px;
  margin-bottom: 15px;
}

.alert-success {
  background: #4caf50;
  color: #fff;
}

.alert-error {
  background: #f44336;
  color: #fff;
}
</style>
