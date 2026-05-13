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
  console.log(JSON.stringify({ label, signature: sig, computeUnitsConsumed: cu, tokenInvokeCount }, null, 2));
  return { sig, cu, tokenInvokeCount };
}

async function main() {
  console.log('payer', payer.publicKey.toBase58());
  console.log('program', programId.toBase58());

  const mint = await createMint(connection, payer, payer.publicKey, null, 6, undefined, undefined, TOKEN_PROGRAM_ID);
  const source = await createTokenAccount(mint, payer.publicKey);
  const destinationA = await createTokenAccount(mint, payer.publicKey);
  const destinationB = await createTokenAccount(mint, payer.publicKey);
  await mintTo(connection, payer, mint, source, payer, 1_000_000_000n, [], undefined, TOKEN_PROGRAM_ID);

  const amountA = 10_000;
  const amountB = 20_000;
  const keys = [
    { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    { pubkey: source, isSigner: false, isWritable: true },
    { pubkey: mint, isSigner: false, isWritable: false },
    { pubkey: destinationA, isSigner: false, isWritable: true },
    { pubkey: destinationB, isSigner: false, isWritable: true },
    { pubkey: payer.publicKey, isSigner: true, isWritable: false },
  ];

  await sendProofIx('double_transfer_checked', encodeTransferArgs(1, amountA, amountB, 6), keys);
  await sendProofIx('batch_transfer_checked', encodeTransferArgs(2, amountA, amountB, 6), keys);
  await sendProofIx('batch_prepared_transfer_checked', encodeTransferArgs(3, amountA, amountB, 6), keys);

  const sourceAccount = await getAccount(connection, source, 'confirmed', TOKEN_PROGRAM_ID);
  const destinationAAccount = await getAccount(connection, destinationA, 'confirmed', TOKEN_PROGRAM_ID);
  const destinationBAccount = await getAccount(connection, destinationB, 'confirmed', TOKEN_PROGRAM_ID);
  console.log(JSON.stringify({
    mint: mint.toBase58(),
    source: source.toBase58(),
    destinationA: destinationA.toBase58(),
    destinationB: destinationB.toBase58(),
    balances: {
      source: sourceAccount.amount.toString(),
      destinationA: destinationAAccount.amount.toString(),
      destinationB: destinationBAccount.amount.toString(),
    },
  }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
