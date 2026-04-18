import '../api_client.dart';
import '../models/link_entry.dart';

class LinksRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<LinkEntry>> list() async {
    final res = await _dio.get('/links');
    return (res.data as List)
        .map((e) => LinkEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LinkEntry> create(LinkEntry l) async {
    final res = await _dio.post('/links', data: l.toCreateJson());
    return LinkEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LinkEntry> update(String id, LinkEntry l) async {
    final res = await _dio.patch('/links/$id', data: l.toCreateJson());
    return LinkEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/links/$id');
  }
}
