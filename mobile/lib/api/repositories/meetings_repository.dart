import '../api_client.dart';
import '../models/meeting.dart';

class MeetingsRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<Meeting>> list() async {
    final res = await _dio.get('/meetings');
    return (res.data as List)
        .map((e) => Meeting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Meeting> create(Meeting m) async {
    final res = await _dio.post('/meetings', data: m.toCreateJson());
    return Meeting.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Meeting> update(String id, Meeting m) async {
    final res = await _dio.patch('/meetings/$id', data: m.toCreateJson());
    return Meeting.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/meetings/$id');
  }
}
