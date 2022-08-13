/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_web3/instruction.dart';
import 'package:solana_web3/buffer.dart';
import 'package:solana_web3/buffer_layout.dart' as buffer_layout;
import 'package:solana_web3/layout.dart' as layout;
import 'package:solana_web3/message_instruction.dart';
import 'package:solana_web3/models/address_table_lookup.dart';
import 'package:solana_web3/nacl.dart' as nacl show publicKeyLength;
import 'package:solana_web3/rpc_config/get_block_config.dart';
import 'package:solana_web3/models/serialisable.dart';
import 'package:solana_web3/models/transaction.dart';
import 'package:solana_web3/public_key.dart';
import 'package:solana_web3/transaction_constants.dart' show packetDataSize;
import 'package:solana_web3/utils/convert.dart' as convert;
import 'package:solana_web3/utils/shortvec.dart' as shortvec;


/// Message Header
/// ------------------------------------------------------------------------------------------------

class MessageHeader extends Serialisable {
  
  /// Details the account types and signatures required by the transaction (signed and read-only 
  /// accounts).
  const MessageHeader({
    required this.numRequiredSignatures,
    required this.numReadonlySignedAccounts,
    required this.numReadonlyUnsignedAccounts,
  });

  /// The total number of signatures required to make the transaction valid. The signatures must 
  /// match the first `numRequiredSignatures` of [Message.accountKeys].
  /// 
  /// ### Example:
  /// 
  ///   If [Transaction.signatures] = `['signature1', 'signature0', 'signature2']`,
  /// 
  ///   then [numRequiredSignatures] must = `3`,
  /// 
  ///   and the first `3` public keys in [Message.accountKeys] will be the [Transaction.signatures]' 
  ///   corresponding public keys in the same order `['pk1', 'pk0', 'pk2', ...]`.
  final int numRequiredSignatures;

  /// The last `numReadonlySignedAccounts` of the signed keys are read-only accounts.
  final int numReadonlySignedAccounts;

  /// The last numReadonlyUnsignedAccounts of the unsigned keys are read-only accounts.
  final int numReadonlyUnsignedAccounts;

  /// Creates an instance of `this` class from the constructor parameters defined in the [json] 
  /// object.
  /// 
  /// ```
  /// MessageHeader.fromJson({ '<parameter>': <value> });
  /// ```
  factory MessageHeader.fromJson(final Map<String, dynamic> json) => MessageHeader(
    numRequiredSignatures: json['numRequiredSignatures'],
    numReadonlySignedAccounts: json['numReadonlySignedAccounts'],
    numReadonlyUnsignedAccounts: json['numReadonlyUnsignedAccounts'],
  );

  @override
  Map<String, dynamic> toJson() => {
    'numRequiredSignatures': numRequiredSignatures,
    'numReadonlySignedAccounts': numReadonlySignedAccounts,
    'numReadonlyUnsignedAccounts': numReadonlyUnsignedAccounts,
  };
}


/// Message
/// ------------------------------------------------------------------------------------------------

class Message extends Serialisable {
  
  /// Defines the list of [instructions] to be processed atomically by a transaction.
  Message({
    required this.accountKeys,
    required this.header,
    required this.recentBlockhash,
    required this.instructions,
    this.addressTableLookups,
  }) {
    for (final Instruction instruction in instructions) { 
      final int index = instruction.programIdIndex;
      _indexToProgramIds[index] = accountKeys[index];
    }
  }

  /// List of base-58 encoded public keys used by the transaction, including the instructions and 
  /// signatures. The first [Message.header.numRequiredSignatures] public keys must sign the 
  /// transaction.
  /// 
  /// ### Example:
  /// 
  ///   If [accountKeys] = `['pk1', 'pk0', 'pk4', 'pk2', 'pk5']`,
  /// 
  ///   and [Message.header.numRequiredSignatures] = `2`,
  /// 
  ///   then [Transaction.signatures] must = `['message signed by pk1', 'message signed by pk0']`
  ///
  final List<PublicKey> accountKeys;

  /// The account types and signatures required by the transaction.
  final MessageHeader header;

   /// A base-58 encoded hash of a recent block in the ledger used to prevent transaction 
   /// duplication and to give transactions lifetimes.
  final String recentBlockhash;

  /// A list of program instructions that will be executed in sequence and committed in one atomic 
  /// transaction if all succeed.
  final Iterable<Instruction> instructions;

  /// A list of address table lookups used by a transaction to dynamically load addresses from 
  /// on-chain address lookup tables, or `null` if [GetBlockConfig.maxSupportedTransactionVersion] 
  /// is not set.
  final List<AddressTableLookup>? addressTableLookups;

  /// Map each program id index to its corresponding account key.
  final Map<int, PublicKey> _indexToProgramIds = {};

  /// Creates an instance of `this` class from the constructor parameters defined in the [json] 
  /// object.
  /// 
  /// ```
  /// Message.fromJson({ '<parameter>': <value> });
  /// ```
  factory Message.fromJson(final Map<String, dynamic> json) => Message(
    accountKeys: convert.list.decode(json['accountKeys'], PublicKey.fromString),
    header: MessageHeader.fromJson(json['header']),
    recentBlockhash: json['recentBlockhash'],
    instructions: convert.list.decode(json['instructions'], Instruction.fromJson),
    addressTableLookups: convert.list.tryDecode(json['addressTableLookups'], AddressTableLookup.fromJson),
  );

  @override
  Map<String, dynamic> toJson() => {
    'accountKeys': accountKeys.map((PublicKey key) => key.toBase58()),
    'header': header.toJson(),
    'recentBlockhash': recentBlockhash,
    'instructions': convert.list.encode(instructions),
    'addressTableLookups': convert.list.tryEncode(addressTableLookups),
  };

  /// Check if the account at [index] is a signer account.
  bool isAccountSigner(final int index) {
    return index < header.numRequiredSignatures;
  }

  /// Check if the account at [index] is a writable account.
  bool isAccountWritable(final int index) {
    return index < header.numRequiredSignatures - header.numReadonlySignedAccounts 
      || (index >= header.numRequiredSignatures 
          && index < accountKeys.length - header.numReadonlyUnsignedAccounts);
  }

  /// Check if the account at [index] is a program account.
  bool isProgramId(final int index) {
    return _indexToProgramIds.containsKey(index);
  }

  /// The programs accounts.
  Iterable<PublicKey> get programIds {
    return _indexToProgramIds.values;
  }

  /// The non-programs accounts.
  Iterable<PublicKey> get nonProgramIds {
    int index = 0;
    return accountKeys.where((_) => !isProgramId(index++));
  }

  /// Encodes this message into a buffer.
  Buffer serialise() {

    final int keysLength = accountKeys.length;

    final List<int> keyCount = shortvec.encodeLength(keysLength);

    final Iterable<MessageInstruction> instructions = this.instructions.map(
      MessageInstruction.fromInstruction
    );

    final Buffer instructionCount = Buffer.fromList(shortvec.encodeLength(instructions.length));
    print('PK SIZE $packetDataSize = INS COUNT $instructionCount');
    Buffer instructionBuffer = Buffer(packetDataSize)..setAll(0, instructionCount);
    int instructionBufferLength = instructionCount.length;

    for (final MessageInstruction instruction in instructions) {
      
      final buffer_layout.Structure instructionLayout = buffer_layout.struct([
        buffer_layout.u8('programIdIndex'),
        buffer_layout.blob(
          instruction.keyIndicesCount.length,
          'keyIndicesCount',
        ),
        buffer_layout.seq(
          buffer_layout.u8('keyIndex'),
          instruction.keyIndices.length,
          'keyIndices',
        ),
        buffer_layout.blob(instruction.dataLength.length, 'dataLength'),
        buffer_layout.seq(
          buffer_layout.u8('userdatum'),
          instruction.data.length,
          'data',
        ),
      ]);

      instructionBufferLength += instructionLayout.encode(
        instruction.toJson(),
        instructionBuffer,
        instructionBufferLength,
      );
    }

    instructionBuffer = instructionBuffer.slice(0, instructionBufferLength);

    final signDataLayout = buffer_layout.struct([
      buffer_layout.blob(1, 'numRequiredSignatures'),
      buffer_layout.blob(1, 'numReadonlySignedAccounts'),
      buffer_layout.blob(1, 'numReadonlyUnsignedAccounts'),
      buffer_layout.blob(keyCount.length, 'keyCount'),
      buffer_layout.seq(layout.publicKey('key'), keysLength, 'keys'),
      layout.publicKey('recentBlockhash'),
    ]);

    final transaction = {
      'numRequiredSignatures': Buffer.fromList([header.numRequiredSignatures]),
      'numReadonlySignedAccounts': Buffer.fromList([header.numReadonlySignedAccounts]),
      'numReadonlyUnsignedAccounts': Buffer.fromList([header.numReadonlyUnsignedAccounts]),
      'keyCount': Buffer.fromList(keyCount),
      'keys': accountKeys.map((key) => Buffer.fromList(key.toBytes())),
      'recentBlockhash': convert.base58.decode(recentBlockhash),
    };

    final Buffer signData = Buffer(2048);
    final int length = signDataLayout.encode(transaction, signData);
    instructionBuffer.copy(signData, length);
    return signData.slice(0, length + instructionBuffer.length);
  }

  /// Decodes a message into a [Message] instance.
  factory Message.fromList(final List<int> byteArray) {
    return Message.fromBuffer(Buffer.fromList(byteArray));
  }

  /// Decodes a message into a [Message] instance.
  factory Message.fromBuffer(Buffer buffer) {

    final int numRequiredSignatures = buffer[0];
    final int numReadonlySignedAccounts = buffer[1];
    final int numReadonlyUnsignedAccounts = buffer[2];
    buffer = buffer.slice(3);

    final int accountCount = shortvec.decodeLength(buffer.asUint8List());
    final List<PublicKey> accountKeys = [];
    for (int i = 0; i < accountCount; ++i) {
      final Buffer account = buffer.slice(0, nacl.publicKeyLength);
      buffer = buffer.slice(nacl.publicKeyLength);
      accountKeys.add(PublicKey.fromUint8List(account.asUint8List()));
    }

    final Buffer recentBlockhash = buffer.slice(0, nacl.publicKeyLength);
    buffer = buffer.slice(nacl.publicKeyLength);

    final int instructionCount = shortvec.decodeLength(buffer.asUint8List());
    final List<Instruction> instructions = [];
    for (int i = 0; i < instructionCount; ++i) {
      final int programIdIndex = buffer.asUint8List().removeAt(0);
      final int accountCount = shortvec.decodeLength(buffer.asUint8List());
      final Buffer accounts = buffer.slice(0, accountCount);
      buffer = buffer.slice(accountCount);
      final int dataLength = shortvec.decodeLength(buffer.asUint8List());
      final Buffer dataSlice = buffer.slice(0, dataLength);
      final String data = convert.base58.encode(dataSlice.asUint8List());
      buffer = buffer.slice(dataLength);
      instructions.add(
        Instruction(
          programIdIndex: programIdIndex, 
          accounts: accounts.asUint8List(), 
          data: data,
        )
      );
    }

    return Message(
      accountKeys: accountKeys,
      header: MessageHeader(
        numRequiredSignatures: numRequiredSignatures, 
        numReadonlySignedAccounts: numReadonlySignedAccounts,
        numReadonlyUnsignedAccounts: numReadonlyUnsignedAccounts,
      ), 
      recentBlockhash: convert.base58.encode(recentBlockhash.asUint8List()), 
      instructions: instructions,
    );
  }
}