/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_web3/config/account_encoding.dart';
import 'package:solana_web3/config/commitment.dart';
import 'package:solana_web3/models/data_slice.dart';
import 'package:solana_web3/rpc/rpc_request_config.dart';
import 'package:solana_web3/utils/types.dart' show u64;


/// Get Account Info Config
/// ------------------------------------------------------------------------------------------------

class GetAccountInfoConfig extends RpcRequestConfig {

  /// JSON-RPC configurations for `getAccountInfo` methods.
  GetAccountInfoConfig({
    super.id,
    super.headers,
    super.timeout,
    this.commitment,
    this.encoding = AccountEncoding.base64,
    this.dataSlice,
    this.minContextSlot,
  }): assert(encoding.isAccount, 'Invalid encoding.'),
      assert(dataSlice == null || encoding.isBinary, 'Must use binary encoding for [DataSlice].'),
      assert(minContextSlot == null || minContextSlot >= 0);

  /// The type of block to query for the request (default: [Commitment.finalized]).
  final Commitment? commitment;

  /// The account data's encoding (default: [AccountEncoding.base64]). 
  /// 
  /// If [dataSlice] is provided, encoding is limited to `base58`, `base64` or `base64+zstd`.
  final AccountEncoding encoding;

  /// Limit the returned account data to the range [DataSlice.offset] : [DataSlice.offset] + 
  /// [DataSlice.length].
  final DataSlice? dataSlice;

  /// The minimum slot that the request can be evaluated at.
  final u64? minContextSlot;

  @override
  Map<String, dynamic> object() => {
    'commitment': commitment?.name,
    'encoding': encoding.name,
    'dataSlice': dataSlice?.toJson(),
    'minContextSlot': minContextSlot,
  };
}