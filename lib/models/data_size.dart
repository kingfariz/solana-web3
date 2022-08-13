/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:solana_web3/models/serialisable.dart';
import 'package:solana_web3/utils/types.dart' show u64;


/// Data Size
/// ------------------------------------------------------------------------------------------------

class DataSize extends Serialisable {

  /// Program account filter.
  const DataSize({
    required this.dataSize,
  });

  /// Compares the program account data length with the provided data size.
  final u64 dataSize;

  /// Creates an instance of `this` class from the constructor parameters defined in the [json] 
  /// object.
  /// 
  /// ```
  /// DataSize.fromJson({ '<parameter>': <value> });
  /// ```
  factory DataSize.fromJson(final Map<String, dynamic> json) => DataSize(
    dataSize: json['dataSize'],
  );
  
  /// Creates an instance of `this` class from the constructor parameters defined in the [json] 
  /// object.
  /// 
  /// Returns `null` if [json] is omitted.
  /// 
  /// ```
  /// DataSize.fromJson({ '<parameter>': <value> });
  /// ```
  static DataSize? tryFromJson(final Map<String, dynamic>? json) {
    return json == null ? null : DataSize.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson() => {
    'dataSize': dataSize,
  };
}