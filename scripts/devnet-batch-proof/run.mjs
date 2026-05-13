import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import {
  ACCOUNT_SIZE,
  createInitializeAccountInstruction,
  createMint,
  getAccount,
  getMinimumBalanceForRentExemptAccount,
  mintTo,
  TOKEN_PROGRAM_ID,
} from '@solana/spl-token';

const RPC_URL = process.env.RPC_URL ?? 'https://api.devnet.solana.com';
const PROGRAM_ID = process.env.BATCH_PROOF_PROGRAM_ID;
if (!PROGRAM_ID) throw new Error('Set BATCH_PROOF_PROGRAM_ID to the deployed batch_proof program id');

const programId = new PublicKey(PROGRAM_ID);
const connection = new Connection(RPC_URL, 'confirmed');
const payerPath = process.env.SOLANA_KEYPAIR ?? path.join(os.homedir(), '.config/solana/id.json');
const payer = Keypair.fromSecretKey(Uint8Array.from(JSON.parse(fs.readFileSync(payerPath, 'utf8'))));

function encodeTransferArgs(tag, amountA, amountB, decimals) {
  const buf = Buffer.alloc(18);
  buf.writeUInt8(tag, 0);
  buf.writeBigUInt64LE(BigInt(amountA), 1);
  buf.writeBigUInt64LE(BigInt(amountB), 9);
  buf.writeUInt8(decimals, 17);
  return buf;
}

async function createTokenAccount(mint, owner) {
  const account = Keypair.generate();
  const rent = await getMinimumBalanceForRentExemptAccount(connection);
  const tx = new Transaction().add(
    SystemProgram.createAccount({
      fromPubkey: payer.publicKey,
      newAccountPubkey: account.publicKey,
      lamports: rent,
      space: ACCOUNT_SIZE,
      programId: TOKEN_PROGRAM_ID,
    }),
    createInitializeAccountInstruction(account.publicKey, mint, owner, TOKEN_PROGRAM_ID),
  );
  await sendAndConfirmTransaction(connection, tx, [payer, account], { commitment: 'confirmed' });
  return account.publicKey;
}

function countTokenInvokes(tx) {
  return (tx?.meta?.logMessages ?? []).filter((line) =>
    line.includes(`Program ${TOKEN_PROGRAM_ID.toBase58()} invoke`),
  ).length;
}

async function sendProofIx(label, data, keys) {
  const ix = new TransactionInstruction({ programId, keys, data });
  const sig = await sendAndConfirmTransaction(connection, new Transaction().add(ix), [payer], {
    commitment: 'confirmed',
  });
  const tx = await connection.getTransaction(sig, {
    commitment: 'confirmed',
    maxSupportedTransactionVersion: 0,
  });
  const cu = tx?.meta?.computeUnitsConsumed ?? null;
  const tokenInvokeCount = countTokenInvokes(tx);
  const result = { label, signature: sig, computeUnitsConsumed: cu, tokenInvokeCount };
  console.log(JSON.stringify(result, null, 2));
  return result;
}

async function ensurePdaState() {
  const [pdaState, bump] = PublicKey.findProgramAddressSync([Buffer.from('vault')], programId);
  const info = await connection.getAccountInfo(pdaState, 'confirmed');
  if (info) {
    console.log('pda_state', pdaState.toBase58(), 'already initialized');
    return { pdaState, bump, created: false };
  }

  const mint = await createMint(connection, payer, payer.publicKey, null, 6, undefined, undefined, TOKEN_PROGRAM_ID);
  const userSource = await createTokenAccount(mint, payer.publicKey);
  const destinationA = await createTokenAccount(mint, payer.publicKey);
  const destinationB = await createTokenAccount(mint, payer.publicKey);
  const vaultSource = await createTokenAccount(mint, payer.publicKey);

  const initKeys = [
    { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    { pubkey: userSource, isSigner: false, isWritable: true },
    { pubkey: mint, isSigner: false, isWritable: false },
    { pubkey: destinationA, isSigner: false, isWritable: true },
    { pubkey: destinationB, isSigner: false, isWritable: true },
    { pubkey: payer.publicKey, isSigner: true, isWritable: true },
    { pubkey: vaultSource, isSigner: false, isWritable: true },
    { pubkey: pdaState, isSigner: false, isWritable: true },
    { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
  ];
  await sendProofIx('init_pda', Buffer.from([0, bump]), initKeys);
  return { pdaState, bump, created: true };
}

function simpleKeys(source, mint, destinationA, destinationB, extraAccount, pdaState) {
  return [
    { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    { pubkey: source, isSigner: false, isWritable: true },
    { pubkey: mint, isSigner: false, isWritable: false },
    { pubkey: destinationA, isSigner: false, isWritable: true },
    { pubkey: destinationB, isSigner: false, isWritable: true },
    { pubkey: payer.publicKey, isSigner: true, isWritable: false },
    { pubkey: extraAccount, isSigner: false, isWritable: false },
    { pubkey: pdaState, isSigner: false, isWritable: false },
    { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
  ];
}

function mixedKeys(userSource, mint, destinationA, destinationB, vaultSource, pdaState) {
  return [
    { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    { pubkey: userSource, isSigner: false, isWritable: true },
    { pubkey: mint, isSigner: false, isWritable: false },
    { pubkey: destinationA, isSigner: false, isWritable: true },
    { pubkey: destinationB, isSigner: false, isWritable: true },
    { pubkey: payer.publicKey, isSigner: true, isWritable: false },
    { pubkey: vaultSource, isSigner: false, isWritable: true },
    { pubkey: pdaState, isSigner: false, isWritable: false },
    { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
  ];
}

function swapKeys(userSourceA, mintA, vaultA, userDestinationB, vaultB, pdaState, mintB) {
  return [
    { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    { pubkey: userSourceA, isSigner: false, isWritable: true },
    { pubkey: mintA, isSigner: false, isWritable: false },
    { pubkey: vaultA, isSigner: false, isWritable: true },
    { pubkey: userDestinationB, isSigner: false, isWritable: true },
    { pubkey: payer.publicKey, isSigner: true, isWritable: false },
    { pubkey: vaultB, isSigner: false, isWritable: true },
    { pubkey: pdaState, isSigner: false, isWritable: false },
    { pubkey: mintB, isSigner: false, isWritable: false },
  ];
}

async function createSimpleScenario() {
  const mint = await createMint(connection, payer, payer.publicKey, null, 6, undefined, undefined, TOKEN_PROGRAM_ID);
  const source = await createTokenAccount(mint, payer.publicKey);
  const destinationA = await createTokenAccount(mint, payer.publicKey);
  const destinationB = await createTokenAccount(mint, payer.publicKey);
  const extraAccount = await createTokenAccount(mint, payer.publicKey);
  await mintTo(connection, payer, mint, source, payer, 1_000_000_000n, [], undefined, TOKEN_PROGRAM_ID);
  return { mint, source, destinationA, destinationB, extraAccount };
}

async function createMixedScenario(pdaState) {
  const mint = await createMint(connection, payer, payer.publicKey, null, 6, undefined, undefined, TOKEN_PROGRAM_ID);
  const userSource = await createTokenAccount(mint, payer.publicKey);
  const destinationA = await createTokenAccount(mint, payer.publicKey);
  const destinationB = await createTokenAccount(mint, payer.publicKey);
  const vaultSource = await createTokenAccount(mint, pdaState);
  await mintTo(connection, payer, mint, userSource, payer, 1_000_000_000n, [], undefined, TOKEN_PROGRAM_ID);
  await mintTo(connection, payer, mint, vaultSource, payer, 1_000_000_000n, [], undefined, TOKEN_PROGRAM_ID);
  return { mint, userSource, destinationA, destinationB, vaultSource };
}

async function createSwapScenario(pdaState) {
  const mintA = await createMint(connection, payer, payer.publicKey, null, 6, undefined, undefined, TOKEN_PROGRAM_ID);
  const mintB = await createMint(connection, payer, payer.publicKey, null, 6, undefined, undefined, TOKEN_PROGRAM_ID);
  const userSourceA = await createTokenAccount(mintA, payer.publicKey);
  const vaultA = await createTokenAccount(mintA, pdaState);
  const userDestinationB = await createTokenAccount(mintB, payer.publicKey);
  const vaultB = await createTokenAccount(mintB, pdaState);
  await mintTo(connection, payer, mintA, userSourceA, payer, 1_000_000_000n, [], undefined, TOKEN_PROGRAM_ID);
  await mintTo(connection, payer, mintB, vaultB, payer, 1_000_000_000n, [], undefined, TOKEN_PROGRAM_ID);
  return { mintA, mintB, userSourceA, vaultA, userDestinationB, vaultB };
}

async function fetchBalances(label, accounts) {
  const entries = await Promise.all(
    Object.entries(accounts).map(async ([name, pubkey]) => {
      const account = await getAccount(connection, pubkey, 'confirmed', TOKEN_PROGRAM_ID);
      return [name, account.amount.toString()];
    }),
  );
  console.log(JSON.stringify({ label, balances: Object.fromEntries(entries) }, null, 2));
}

async function runSimpleFamily(prefix, baseTag, pdaState) {
  const scenario = await createSimpleScenario();
  const keys = simpleKeys(
    scenario.source,
    scenario.mint,
    scenario.destinationA,
    scenario.destinationB,
    scenario.extraAccount,
    pdaState,
  );
  const amountA = 10_000;
  const amountB = 20_000;
  const results = [];
  results.push(await sendProofIx(`${prefix}_double`, encodeTransferArgs(baseTag, amountA, amountB, 6), keys));
  results.push(await sendProofIx(`${prefix}_batch`, encodeTransferArgs(baseTag + 1, amountA, amountB, 6), keys));
  results.push(await sendProofIx(`${prefix}_batch_prepared`, encodeTransferArgs(baseTag + 2, amountA, amountB, 6), keys));
  await fetchBalances(prefix, {
    source: scenario.source,
    destinationA: scenario.destinationA,
    destinationB: scenario.destinationB,
  });
  return results;
}

async function runMixedFamily(pdaState) {
  const scenario = await createMixedScenario(pdaState);
  const keys = mixedKeys(
    scenario.userSource,
    scenario.mint,
    scenario.destinationA,
    scenario.destinationB,
    scenario.vaultSource,
    pdaState,
  );
  const amountA = 30_000;
  const amountB = 15_000;
  const results = [];
  results.push(await sendProofIx('mixed_checked_double', encodeTransferArgs(7, amountA, amountB, 6), keys));
  results.push(await sendProofIx('mixed_checked_batch', encodeTransferArgs(8, amountA, amountB, 6), keys));
  results.push(await sendProofIx('mixed_checked_batch_prepared', encodeTransferArgs(9, amountA, amountB, 6), keys));
  await fetchBalances('mixed_checked', {
    userSource: scenario.userSource,
    vaultSource: scenario.vaultSource,
    destinationA: scenario.destinationA,
    destinationB: scenario.destinationB,
  });
  return results;
}

async function runSwapFamily(pdaState) {
  const scenario = await createSwapScenario(pdaState);
  const keys = swapKeys(
    scenario.userSourceA,
    scenario.mintA,
    scenario.vaultA,
    scenario.userDestinationB,
    scenario.vaultB,
    pdaState,
    scenario.mintB,
  );
  const amountIn = 25_000;
  const amountOut = 12_500;
  const results = [];
  results.push(await sendProofIx('swap_checked_double', encodeTransferArgs(10, amountIn, amountOut, 6), keys));
  results.push(await sendProofIx('swap_checked_batch', encodeTransferArgs(11, amountIn, amountOut, 6), keys));
  results.push(await sendProofIx('swap_checked_batch_prepared', encodeTransferArgs(12, amountIn, amountOut, 6), keys));
  await fetchBalances('swap_checked', {
    userSourceA: scenario.userSourceA,
    vaultA: scenario.vaultA,
    vaultB: scenario.vaultB,
    userDestinationB: scenario.userDestinationB,
  });
  return results;
}

function printSummary(results) {
  console.log('\nSummary');
  for (const result of results) {
    console.log(
      `${result.label}: ${result.computeUnitsConsumed} CU, token invokes ${result.tokenInvokeCount}, sig ${result.signature}`,
    );
  }
}

async function main() {
  console.log('payer', payer.publicKey.toBase58());
  console.log('program', programId.toBase58());

  const { pdaState, bump } = await ensurePdaState();
  console.log('pda_state', pdaState.toBase58(), 'bump', bump);

  const results = [];
  results.push(...(await runSimpleFamily('transfer', 1, pdaState)));
  results.push(...(await runSimpleFamily('transfer_checked', 4, pdaState)));
  results.push(...(await runMixedFamily(pdaState)));
  results.push(...(await runSwapFamily(pdaState)));
  printSummary(results);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
