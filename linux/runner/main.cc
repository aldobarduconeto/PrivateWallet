#include "my_application.h"

// Inicia o aplicativo GTK com os argumentos recebidos na linha de comando.
int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
