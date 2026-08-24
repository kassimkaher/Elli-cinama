import '../../../../core/network/content_client.dart';
import '../../../../core/network/request_builder.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/account.dart';
import '../models/account_model.dart';

class AuthRemoteDataSource {
  final ContentClient client;
  final ContentRequestBuilder builder;

  AuthRemoteDataSource({required this.client, required this.builder});

  Future<Result<Account>> login({
    required String username,
    required String password,
  }) {
    final payload = builder.buildLogin(username: username, password: password);
    return client.callObject<Account>(
      payload: payload,
      decoder: (json) => AccountModel.fromJson(json as Map),
    );
  }
}
