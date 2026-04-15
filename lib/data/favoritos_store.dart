import 'package:shared_preferences/shared_preferences.dart';

class FavoritosStore {
  static const _key = 'favoritos_empresas';

  static Future<Set<int>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_key) ?? [];
    return lista.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
  }

  static Future<bool> isFavorito(int idEmpresa) async {
    final favs = await getAll();
    return favs.contains(idEmpresa);
  }

  static Future<void> toggle(int idEmpresa) async {
    final prefs = await SharedPreferences.getInstance();
    final favs  = await getAll();
    if (favs.contains(idEmpresa)) {
      favs.remove(idEmpresa);
    } else {
      favs.add(idEmpresa);
    }
    await prefs.setStringList(_key, favs.map((e) => e.toString()).toList());
  }
}
