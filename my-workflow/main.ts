import {
  EVMClient,
  handler,
  Runner,
  getNetwork,
  CronCapability,
  hexToBase64,
  bytesToHex,
  TxStatus, type Runtime
} from "@chainlink/cre-sdk"
import { Address, encodeAbiParameters, parseAbiParameters } from "viem"



type Config = {
  schedule: string
  chainSelectorName: string
  chainSelectorNameAnvil: string
  consumerAddress: string
  gasLimit: string
  zahl: string
}

export const writeDataOnchain = (runtime: Runtime<Config>): string => {
  const zahl = BigInt(runtime.config.zahl)

  // Get network info
  const network = getNetwork({
    chainFamily: "evm",
    chainSelectorName: runtime.config.chainSelectorName,
  })

  if (!network) {
    throw new Error(`Network not found: ${runtime.config.chainSelectorName}`)
  }

  // Create EVM client
  const evmClient = new EVMClient(network.chainSelector.selector)

  // 1. Encode your data 
  // For a single uint256
  const reportData = encodeAbiParameters(
    parseAbiParameters("uint256"),
    [zahl]
  )

  runtime.log(`Encoded data for consumer contract`)

  // 2. Generate signed report
  const reportResponse = runtime
    .report({
      encodedPayload: hexToBase64(reportData),
      encoderName: "evm",
      signingAlgo: "ecdsa",
      hashingAlgo: "keccak256",
    })
    .result()

  runtime.log(`Generated signed report`)

  // 3. Submit to blockchain
  const writeResult = evmClient
    .writeReport(runtime, {
      receiver: runtime.config.consumerAddress,
      report: reportResponse,
      gasConfig: {
        gasLimit: runtime.config.gasLimit,
      },
    })
    .result()

  // 4. Check status and return
  if (writeResult.txStatus === TxStatus.SUCCESS) {
    const txHash = bytesToHex(writeResult.txHash || new Uint8Array(32))
    runtime.log(`Transaction successful: ${txHash}`)
    return txHash
  }

  throw new Error(`Transaction failed with status: ${writeResult.txStatus}`)
};

const initWorkflow = (config: Config) => {
  const cron = new CronCapability()
  return [
    handler(
      cron.trigger({
        schedule: config.schedule,
      }),
      writeDataOnchain
    ),
  ]
}

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}
