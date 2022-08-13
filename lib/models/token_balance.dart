/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_web3/models/serialisable.dart';
import 'package:solana_web3/models/ui_token_amount.dart';


/// Token Balance
/// ------------------------------------------------------------------------------------------------

class TokenBalance extends Serialisable {

  /// The Solana runtime records the cross-program instructions that are invoked during transaction 
  /// processing and makes these available for greater transparency of what was executed on-chain 
  /// per transaction instruction.
  const TokenBalance({
    required this.accountIndex,
    required this.mint,
    required this.owner,
    required this.uiTokenAmount,
  });

  /// The index of the account in which the token balance is provided for.
  final num accountIndex;

  /// The token's mint address (public key).
  final String mint;

  /// The token balance owner's address (public key).
  final String owner;

  /// Token amount details.
  final UITokenAmount uiTokenAmount;

  /// Create an instance of this class from the given [json] object.
  /// 
  /// @param [json]: A map containing the class' constructor parameters.
  factory TokenBalance.fromJson(final Map<String, dynamic> json) => TokenBalance(
    accountIndex: json['accountIndex'], 
    mint: json['mint'],
    owner: json['owner'],
    uiTokenAmount: UITokenAmount.fromJson(json['uiTokenAmount']),
  );

  @override
  Map<String, dynamic> toJson() => {
    'accountIndex': accountIndex,
    'mint': mint,
    'owner': owner,
    'uiTokenAmount': uiTokenAmount.toJson(),
  };
}