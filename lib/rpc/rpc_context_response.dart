/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_web3/rpc/rpc_context_result.dart';
import 'package:solana_web3/rpc/rpc_response.dart';


/// RPC Context Response
/// ------------------------------------------------------------------------------------------------

typedef RpcContextResponse<T> = RpcResponse<RpcContextResult<T>>;