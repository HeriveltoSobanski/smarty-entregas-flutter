bool cpfValido(String cpf) {
  cpf = cpf.replaceAll(RegExp(r'\D'), '');
  if (cpf.length != 11) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(cpf)) return false;

  int sum = 0;
  for (int i = 0; i < 9; i++) { sum += int.parse(cpf[i]) * (10 - i); }
  int d1 = (sum * 10) % 11;
  if (d1 >= 10) d1 = 0;
  if (d1 != int.parse(cpf[9])) return false;

  sum = 0;
  for (int i = 0; i < 10; i++) { sum += int.parse(cpf[i]) * (11 - i); }
  int d2 = (sum * 10) % 11;
  if (d2 >= 10) d2 = 0;
  return d2 == int.parse(cpf[10]);
}
