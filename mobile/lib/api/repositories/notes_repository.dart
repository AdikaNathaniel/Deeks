import '../api_client.dart';
import '../models/note.dart';

class NotesRepository {
  final _dio = ApiClient.instance.dio;

  Future<List<Note>> list() async {
    final res = await _dio.get('/notes');
    return (res.data as List)
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Note> create(Note n) async {
    final res = await _dio.post('/notes', data: n.toCreateJson());
    return Note.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Note> update(String id, Note n) async {
    final res = await _dio.patch('/notes/$id', data: n.toCreateJson());
    return Note.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete('/notes/$id');
  }
}
