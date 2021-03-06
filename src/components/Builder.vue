<template lang="html">
  <div class="builder-view">
    <div class="form">
      <form ref="form" spellcheck="false">
        <fieldset>
          <h3>Action</h3>
          <div class="actions">
            <ButtonGroup class="row">
              <Button v-for="a in ['normal', 'transfer']" :class="{ active: action === a }" @click="action = a">{{a}}</Button>
            </ButtonGroup>
            <ButtonGroup class="row">
              <Button v-for="a in ['call', 'feeDelegation']" :class="{ active: action === a }" @click="action = a" :disabled="!contractAbi">{{a}}</Button>
            </ButtonGroup>
            <ButtonGroup class="row">
              <Button v-for="a in ['deploy', 'redeploy']" :class="{ active: action === a }" @click="action = a" :disabled="a === 'redeploy' && !contractAbi">{{a}}</Button>
            </ButtonGroup>
            <ButtonGroup class="row">
              <Button v-for="a in ['nameCreate', 'nameUpdate']" :class="{ active: action === a }" @click="action = a">{{a}}</Button>
            </ButtonGroup>
            <ButtonGroup class="row" v-if="consensus === 'dpos'">
              <Button v-for="a in dposActions" :class="{ active: action === a }" @click="action = a">{{a}}</Button>
            </ButtonGroup>
            <ButtonGroup class="row" v-if="consensus === 'raft'">
              <Button v-for="a in raftActions" :class="{ active: action === a }" @click="action = a">{{a}}</Button>
            </ButtonGroup>
          </div>
        </fieldset>

        <fieldset>
          <h3>Recipient</h3>
          <input class="text-input" type="text" @change="$refs.form.reportValidity()" required ref="recipientInput"
            v-model="txBody.to" :disabled="!canEditRecipient">
            
          <h3>Amount</h3>
          <input class="text-input" type="text" pattern="\d+ \w+" @change="$refs.form.reportValidity()" required ref="amountInput"
            v-model="txBody.amount" :disabled="!canEditAmount">
        </fieldset>

        <fieldset v-if="action === 'call' || action === 'feeDelegation'">
          <h3>Contract Method</h3>
          <div class="actions">
            <div class="row">
              <div class="btn-action"
                v-for="func in availableFunctions"
                :class="{ active: contractMethod && contractMethod.name === func.name }"
                @click="contractMethod = func">{{func.name}}</div>
            </div>
          </div>
          <h3>Arguments</h3>
          <div v-if="selectedContractFunction && selectedContractFunction.arguments" class="arguments">
            <div v-for="arg in selectedContractFunction.arguments">
              <h4>{{arg.name}}</h4>
              <input class="text-input" type="text" v-model="contractArgs[arg.name]">
            </div>
          </div>
        </fieldset>

        <fieldset v-if="action === 'nameCreate'">
          <h3>Name</h3>
          <input class="text-input" type="text" required v-model="name.name">
        </fieldset>
        <fieldset v-if="action === 'nameUpdate'">
          <h3>Name</h3>
          <input class="text-input" type="text" required v-model="name.name">
          <h3>New owner</h3>
          <input class="text-input" type="text" required v-model="name.owner">
        </fieldset>
        
        <fieldset v-if="action === 'voteBP'">
          <h3>List of BPs (comma separated)</h3>
          <input class="text-input" type="text" required v-model="vote.candidates">
        </fieldset>

        <fieldset v-if="action === 'voteDAO'">
          <h3>Vote ID</h3>
          <input class="text-input" type="text" required v-model="vote.name">
          <h3>List of candidates (comma separated)</h3>
          <input class="text-input" type="text" required v-model="vote.candidates">
        </fieldset>

        <fieldset v-if="action === 'addAdmin' || action === 'removeAdmin'">
          <h3>Admin address</h3>
          <input class="text-input" type="text" required v-model="raft.admin">
        </fieldset>

        <fieldset v-if="action === 'changeCluster'">
          <h3>Cluster config (JSON)</h3>
          <input class="text-input" type="text" required v-model="raft.jsonArg">
          <span>
            <Icon :size="16" :name="raft.jsonArgValid ? 'checkmark-circle' : 'danger-circle'"></Icon>
            <span v-if="!raft.jsonArgValid" class="note">Enter valid JSON</span>
          </span>
        </fieldset>

        <fieldset v-if="action === 'setConfig' || action === 'removeConfig'">
          <h3>Config key</h3>
          <input class="text-input" type="text" required v-model="raft.configName">
          <h3>Config value</h3>
          <input class="text-input" type="text" required v-model="raft.jsonArg">
        </fieldset>

        <fieldset v-if="action === 'enableConfig'">
          <h3>Config key</h3>
          <input class="text-input" type="text" required v-model="raft.configName">
        </fieldset>

        <fieldset v-if="action === 'deploy' || action === 'redeploy'">
          <h3>Contract Code Payload</h3>
          <input class="text-input" type="file" required @change="handleContractFile" ref="contractCode">
          <p class="note">Output of `aergolua --payload code.lua`</p>

          <h3>Arguments</h3>
          <div v-if="deployConstructorAbi && deployConstructorAbi.length" class="arguments">
            <div v-for="arg in deployConstructorAbi">
              <h4>{{arg.name}}</h4>
              <input class="text-input" type="text" v-model="contractDeployArgs[arg.name]">
            </div>
          </div>

        </fieldset>

      </form>
    </div>
    <div>
      <JsonView :data="txBody" @change="editorChanged"></JsonView>
      <div class="json-view-below">
        <ButtonGroup class="buttons">
          <Button size="big" @click="sign">Sign</Button>
          <Button size="big" type="primary" @click="send">Sign & Send</Button>
        </ButtonGroup>
        <div class="result">
          <div v-if="signature">
            <div class="receipt-status">
              <Icon :size="24" name="checkmark-circle"></Icon>
              <span>Signed</span>
            </div>
            <pre class="receipt-json" >{{signature}}</pre>
          </div>
          <div v-if="receiptStatus === 'loading'">
            <div class="receipt-status">
              <LoadingIndicator :size="24"></LoadingIndicator>
              <span>Waiting for receipt of {{hash}}...</span>
            </div>
          </div>
          <div v-if="receiptStatus === 'loaded'">
            <div class="receipt-status">
              <Icon :size="24" :name="receipt.status === 'ERROR' ? 'danger-circle' : 'checkmark-circle'"></Icon>
              <span>{{receipt.status}} for {{hash}}</span>
            </div>
            <pre class="receipt-json" v-if="receipt">{{JSON.stringify(receipt, null, 2)}}</pre>
          </div>
          <div v-if="receiptStatus === 'error'">
            <div class="receipt-status">
              <Icon :size="24" name="danger-circle"></Icon>
              <span>Failed loading receipt for {{hash}}</span>
            </div>
            <pre class="receipt-json">idk</pre>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { Vue, Component, Watch } from 'vue-property-decorator';
import JsonView from '../components/JsonView.vue';
import { TxTypes, Amount, Address, encodeBuffer, decodeToBytes } from '@herajs/common';
import { Contract } from '@herajs/client';
import { Icon, LoadingIndicator } from './icons/';
import { Button, ButtonGroup } from './buttons/';

const normalActions = ['normal', 'transfer', 'call', 'feeDelegation', 'nameCreate', 'nameUpdate', 'deploy', 'redeploy'] as const;
const dposActions = ['stake', 'unstake', 'voteBP', 'voteDAO'] as const;
const raftActions = ['addAdmin', 'removeAdmin', 'changeCluster', 'setConfig', 'enableConfig', 'removeConfig'] as const;
const actions = [...normalActions, ...dposActions, ...raftActions] as const;
type Action = typeof actions[number];

const defaultTxBody = {
  type: 0,
  from: "",
  to: "",
  amount: "0 aergo",
  limit: 0,
};

function aergoConnectCall(action, responseType, d): Promise<any> {
  const data = {...d};
  if (!d.payload && !d.payload_json) {
    data.payload = '';
  }
  return new Promise((resolve, reject) => {
    window.addEventListener(responseType, function(event) {
      if ('error' in event.detail) {
        reject(event.detail.error);
      } else {
        resolve(event.detail);
      }
    }, { once: true });
    window.postMessage({
      type: 'AERGO_REQUEST',
      action: action,
      data: data,
    }, '*');
  });
}
async function requestSignTx(data) {
  const result = await aergoConnectCall('SIGN_TX', 'AERGO_SIGN_TX_RESULT', data);
  return result.signature;
}
async function requestSendTx(data) {
  const result = await aergoConnectCall('SEND_TX', 'AERGO_SEND_TX_RESULT', data);
  return result.hash;
}

@Component({ components: { JsonView, LoadingIndicator, Icon, Button, ButtonGroup, }})
export default class BuilderView extends Vue {
  action: Action = 'normal';
  dposActions = dposActions;
  raftActions = raftActions;

  txBody = defaultTxBody;
  contractMethod = null;
  contractArgs = {};
  contractDeployPayload = null;
  contractDeployArgs = {};
  deployConstructorAbi = [];

  name = {
    name: '',
    owner: '',
  };

  vote = {
    candidates: '',
    name: '',
  };

  raft = {
    admin: '',
    configName: '',
    jsonArg: '',
    jsonArgValid: false,
  }

  receiptStatus: '' | 'loading' | 'loaded' | 'error' = '';
  receipt: any;
  signature = null;
  hash = null;

  updateTxBody(change) {
    this.txBody = {...this.txBody, ...change};
  }

  @Watch('txBody.amount')
  amountChanged() {
    const $amountInput = this.$refs.amountInput as HTMLInputElement;
    try {
      new Amount($amountInput.value);
      $amountInput.setCustomValidity('');
    } catch(e) {
      $amountInput.setCustomValidity(`${e.message}`);
    }
  }

  @Watch('txBody.to')
  recipientChanged() {
    const $recipientInput = this.$refs.recipientInput as HTMLInputElement;
    try {
      new Address($recipientInput.value);
      $recipientInput.setCustomValidity('');
    } catch(e) {
      $recipientInput.setCustomValidity(`${e.message}`);
    }
  }

  @Watch('contractAddress', { immediate: true })
  contractAddressChanged() {
    this.updateTxBody({ to: this.contractAddress });
  }

  updateContractCallPayload() {
    if (!this.contractMethod) {
      return;
    }
    const payload = {
      Name: this.contractMethod.name,
      Args: this.contractMethod.arguments.map(arg => this.contractArgs[arg.name]),
    };
    this.updateTxBody({ payload_json: payload });
  }

  @Watch('contractMethod')
  contractMethodChanged() {
    this.updateContractCallPayload();
  }

  @Watch('contractArgs', { deep: true })
  contractArgsChanged() {
    this.updateContractCallPayload();
  }

  updateNameTxPayload() {
    if (this.action === 'nameCreate') {
      this.updateTxBody({ payload_json: { Name: 'v1createName', Args: [ this.name.name ]}});
    }
    else if (this.action === 'nameUpdate') {
      this.updateTxBody({ payload_json: { Name: 'v1updateName', Args: [ this.name.name, this.name.owner ]}});
    }
  }

  @Watch('name', { deep: true })
  nameArgsChanged() {
    this.updateNameTxPayload();
  }

  updateRaftPayload() {
    if (this.action === 'addAdmin') {
      this.updateTxBody({ payload_json: { Name: 'appendAdmin', Args: [ this.raft.admin ]}});
    }
    else if (this.action === 'removeAdmin') {
      this.updateTxBody({ payload_json: { Name: 'removeAdmin', Args: [ this.raft.admin ]}});
    }
    else if (this.action === 'changeCluster') {
      try {
        const parsedJson = JSON.parse(this.raft.jsonArg);
        this.raft.jsonArgValid = true;
        this.updateTxBody({ payload_json: { Name: 'changeCluster', Args: [ parsedJson ]}});
      } catch(e) {
        this.raft.jsonArgValid = false;
      }
    }
    else if (this.action === 'setConfig') {
      this.updateTxBody({ payload_json: { Name: 'setConf', Args: [ this.raft.configName, this.raft.jsonArg ]}});
    }
    else if (this.action === 'removeConfig') {
      this.updateTxBody({ payload_json: { Name: 'removeConf', Args: [ this.raft.configName, this.raft.jsonArg ]}});
    }
    else if (this.action === 'enableConfig') {
      this.updateTxBody({ payload_json: { Name: 'enableConf', Args: [ this.raft.configName, true ]}});
    }
  }

  @Watch('raft', { deep: true })
  raftInputChanged() {
    this.updateRaftPayload();
  }

  updateVotePayload() {
    const candidates = this.vote.candidates.split(',');
    if (this.action === 'voteBP') {
      this.updateTxBody({ payload_json: { Name: 'v1voteBP', Args: [ ...candidates ]}});
    }
    else if (this.action === 'voteDAO') {
      this.updateTxBody({ payload_json: { Name: 'v1voteDAO', Args: [ this.vote.name, ...candidates ]}});
    }
  }

  @Watch('vote', { deep: true })
  voteArgsChanged() {
    this.updateVotePayload();
  }

  @Watch('action')
  actionChanged(action: Action) {
    if (action !== 'nameCreate' && action !== 'nameUpdate' && this.txBody.amount === this.namePrice) {
      this.updateTxBody({ amount: '0 aergo' });
    }
    if (action === 'normal') {
      this.updateTxBody({ type: TxTypes.Normal });
    }
    else if (action === 'transfer') {
      this.updateTxBody({ type: TxTypes.Transfer });
    }
    else if (action === 'call') {
      this.updateTxBody({ type: TxTypes.Call, to: this.contractAddress });
      this.updateContractCallPayload();
    }
    else if (action === 'feeDelegation') {
      this.updateTxBody({ type: TxTypes.FeeDelegation, to: this.contractAddress });
      this.updateContractCallPayload();
    }
    else if (action === 'deploy') {
      this.updateTxBody({ type: TxTypes.Deploy, to: '', payload_json: undefined });
    }
    else if (action === 'redeploy') {
      this.updateTxBody({ type: TxTypes.Redeploy, to: this.contractAddress, payload_json: undefined });
    }
    else if (action === 'nameCreate' || action === 'nameUpdate') {
      this.updateTxBody({ type: TxTypes.Governance, to: 'aergo.name', amount: this.namePrice });
      this.updateNameTxPayload();
    }
    else if (dposActions.indexOf(action as typeof dposActions[number]) !== -1 || raftActions.indexOf(action as typeof raftActions[number]) !== -1) {
      let payload_json;
      if (action === 'stake') {
        payload_json = { Name: 'v1stake' };
      }
      else if (action === 'unstake') {
        payload_json = { Name: 'v1unstake' };
      }
      else if (action === 'voteBP') {
        payload_json = { Name: 'v1voteBP', Args: [] };
      }
      else if (action === 'voteDAO') {
        payload_json = { Name: 'v1voteDAO', Args: [] };
      }
      this.updateTxBody({ type: TxTypes.Governance, to: 'aergo.system', payload: undefined, payload_json });
      if (raftActions.indexOf(action as typeof raftActions[number]) !== -1) {
        this.updateRaftPayload();
      }
    }
  }

  updateActionFromTxBody() {
    switch (this.txBody.type) {
      case TxTypes.Normal: this.action = 'normal'; break;
      case TxTypes.Transfer: this.action = 'transfer'; break;
      case TxTypes.Call: this.action = 'call'; break;
      case TxTypes.FeeDelegation: this.action = 'feeDelegation'; break;
      case TxTypes.Deploy: this.action = 'deploy'; break;
      case TxTypes.Redeploy: this.action = 'redeploy'; break;
      case TxTypes.Governance:
        // TODO: more fine-grained action
    }
  }

  editorChanged(txBody) {
    if (txBody) {
      this.txBody = txBody;
      this.updateActionFromTxBody();
    }
  }

  get consensus() {
    return this.$store.state.chainInfo?.chainid?.consensus;
  }

  get namePrice() {
    return `${this.$store.state.chainInfo?.nameprice}`;
  }

  get activeAccount() {
    return this.$store.state.activeAccount;
  }

  @Watch('activeAccount')
  activeAccountChanged() {
    if (this.activeAccount) {
      this.updateTxBody({ from: this.activeAccount.address });
    }
  }

  get contractAddress() {
    return this.$store.state.contract.address;
  }

  get contractAbi() {
    return this.$store.state.contract.abi;
  }

  get availableFunctions() {
    return this.contractAbi.functions.filter(func => !func.view);
  }

  get selectedContractFunction() {
    if (!this.contractMethod) return undefined;
    return this.contractAbi.functions.find(func =>
      func.name === this.contractMethod.name && func.name !== 'constructor' && func.name !== 'default'
    );
  }

  get canEditRecipient() {
    return ['normal', 'transfer', 'redeploy'].indexOf(this.action) !== -1;
  }

  get canEditAmount() {
    const noAmount = [...dposActions, ...raftActions, 'nameCreate', 'nameUpdate'];
    const exceptions = ['stake', 'unstake'];
    return noAmount.indexOf(this.action) === -1 || exceptions.indexOf(this.action) !== -1;
  }

  handleContractFile(): void {
    const $elem = this.$refs.contractCode as HTMLInputElement;
    if (!$elem || !$elem.files || $elem.files.length === 0) return;
    const reader = new FileReader();
    reader.onload = (e) => {
      if (e.target) {
        this.contractDeployPayload = `${e.target.result}`.trim();
        const text = encodeBuffer(decodeToBytes(this.contractDeployPayload, 'base58'), 'ascii');
        const match = text.match(new RegExp(/{"name":"constructor","arguments":(\[.*?\])}/));
        if (match) {
          this.deployConstructorAbi = JSON.parse(match[1]);
        }
      }
    };
    reader.readAsText($elem.files[0]);
  }

  updateContractDeployPayload() {
    const contract = Contract.fromCode(this.contractDeployPayload);
    const args = this.deployConstructorAbi.map(arg => this.contractDeployArgs[arg.name]);
    this.updateTxBody({ payload: encodeBuffer(contract.asPayload(args), 'base64') });
  }

  @Watch('contractDeployPayload')
  contractDeployPayloadChanged() {
    this.updateContractDeployPayload();
  }

  @Watch('contractDeployArgs', { deep: true })
  contractDeployArgsChanged() {
    this.updateContractDeployPayload();
  }

  async sign() {
    const formValid = (this.$refs.form as HTMLFormElement).reportValidity();
    if (!formValid) {
      return;
    }
    this.signature = await requestSignTx(this.txBody);
  }

  async send() {
    const formValid = (this.$refs.form as HTMLFormElement).reportValidity();
    if (!formValid) {
      return;
    }
    this.hash = await requestSendTx(this.txBody);
    this.receiptStatus = 'loading';
    this.receipt = null;
    try {
      this.receipt = await this.$store.dispatch('getReceipt', { hash: this.hash });
      this.receiptStatus = 'loaded';
    } catch(e) {
      console.log(e);
      this.receiptStatus = 'error';
    }
  }
}
</script>

<style lang="scss">
.builder-view {
  display: flex;
  > div {
    flex: 1;
  }
}

.form {
  border-right: 2px solid #242424;

  [disabled] {
    color: #888;
  }

  fieldset {
    padding: 20px 0 20px 20px;
    border: 0;
    border-bottom: 2px solid #242424;

    &:last-child {
      border-bottom: 0;
    }
  }
}

.text-input {
  background-color: #282828;
  line-height: 30px;
  padding: 0 7px;
  min-width: 220px;
  border: 0;
  color: #fff;
  &:focus {
    outline: 1px solid #105db5;
  }
}
h3 {
  font-size: 1em;
  font-weight: bold;
  margin: 20px 0 1em;
  margin-top: 20px;
}
fieldset h3:first-of-type {
  margin-top: 0;
}
.btn-action {
  display: inline-block;
  background-color: #282828;
  line-height: 30px;
  padding: 0 10px;
  min-width: 80px;
  text-align: center;
  margin-right: 8px;
  margin-bottom: 8px;
  border: 1px solid transparent;
  cursor: pointer;
  font-size: .9em;
  &.active {
    border-color:#00C789;
  }
  &:hover {
    background-color: #343434;
  }
  &:disabled {
    cursor: disabled;
  }
}
.actions {
  padding-right: 20px;
  .button {
    margin-bottom: 15px;
  }
  .row.button-group {
    flex-wrap: wrap;
    > * {
      flex: 100px 0 0;
    }
  }
}
.arguments {
  margin-left: 20px;
}
.json-view-below {
  padding: 0 20px;
}
.buttons {
  display: flex;
  margin-top: 20px;
  margin-left: 20px;
  > * {
    flex: 1;
  }
}
.note {
  font-size: .9em;
  opacity: .7;
  margin: .5em 0;
}
.receipt-status {
  margin-top: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  .icon, .loading-indicator {
    margin-right: 10px;
  }
}
.receipt-json {
  white-space: pre-wrap;
  word-break: break-all;
  margin: 20px 0;
  font-size: .9em;
  line-height: 1.3;
  background-color: #282828;
  padding: 4px 6px;
}
</style>