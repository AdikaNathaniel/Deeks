import '../api_client.dart';
import '../models/password_entry.dart';

class PasswordsRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<PasswordEntry>> list() async {
    final res = await _dio.get('/passwords');
    return (res.data as List)
        .map((e) => PasswordEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PasswordEntry> create(PasswordEntry p) async {
    final res = await _dio.post('/passwords', data: p.toCreateJson());
    return PasswordEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PasswordEntry> update(String id, PasswordEntry p) async {
    final res = await _dio.patch('/passwords/$id', data: p.toCreateJson());
    return PasswordEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/passwords/$id');
  }
}
