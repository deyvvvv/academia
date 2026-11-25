import java.math.BigDecimal;
import java.sql.*;
import java.util.Scanner;

public class App {
    private static final String URL = "jdbc:postgresql://localhost:5432/academia", USER = "postgres", PASS = "davibrito777";

    public static void main(String[] args) {
        try (Connection conn = DriverManager.getConnection(URL, USER, PASS);
             Scanner sc = new Scanner(System.in)) {
            int opcao;
            do {
                System.out.print("\n=== ACADEMIA - MENU ===\n1 - Cadastrar aluno (INSERT)\n2 - Listar alunos (SELECT)\n3 - Atualizar nome do aluno (UPDATE)\n4 - Excluir aluno (DELETE)\n5 - Consultar dias restantes (FUNCTION)\n6 - Matricular ou renovar plano (PROCEDURE)\n7 - Registrar check-in (TRIGGER)\n0 - Sair\nEscolha: ");
                opcao = Integer.parseInt(sc.nextLine().trim());
                switch (opcao) {
                    case 1 -> {
                        upd(conn, "INSERT INTO alunos (nome,cpf) VALUES (?,?)",
                                ler(sc, "Nome do aluno: "), ler(sc, "CPF do aluno: "));
                        System.out.println("Aluno cadastrado com sucesso!");
                    }
                    case 2 -> listar(conn);
                    case 3 -> {
                        int id = lerInt(sc, "ID do aluno para atualizar: ");
                        System.out.println(upd(conn, "UPDATE alunos SET nome=? WHERE id_aluno=?", ler(sc, "Novo nome: "), id) > 0
                                ? "Aluno atualizado!" : "Aluno não encontrado.");
                    }
                    case 4 -> System.out.println(upd(conn, "DELETE FROM alunos WHERE id_aluno=?", lerInt(sc, "ID do aluno para excluir: ")) > 0
                            ? "Aluno excluído!" : "Aluno não encontrado.");
                    case 5 -> {
                        int id = lerInt(sc, "ID do aluno: ");
                        try (PreparedStatement ps = conn.prepareStatement("SELECT fn_dias_restantes_matricula(?)")) {
                            ps.setInt(1, id);
                            try (ResultSet rs = ps.executeQuery()) {
                                if (rs.next()) System.out.println("Dias restantes da matrícula: " + rs.getInt(1));
                            }
                        }
                    }
                    case 6 -> {
                        int a = lerInt(sc, "ID do aluno: "), p = lerInt(sc, "ID do plano: ");
                        BigDecimal v = new BigDecimal(ler(sc, "Valor pago (ex: 100.00): "));
                        String f = ler(sc, "Forma de pagamento (PIX, DINHEIRO, CARTAO): ").toUpperCase();
                        try {
                            call(conn, "CALL sp_matricular_ou_renovar(?,?,?,?)", a, p, v, f);
                            System.out.println("Matrícula/renovação realizada e confirmada (COMMIT)!");
                        } catch (SQLException e) {
                            System.out.println("Operação desfeita (ROLLBACK): " + e.getMessage());
                        }
                    }
                    case 7 -> {
                        try {
                            upd(conn, "INSERT INTO checkins (id_aluno) VALUES (?)", lerInt(sc, "ID do aluno para check-in: "));
                            System.out.println("Check-in liberado! Entrada registrada.");
                        } catch (SQLException e) {
                            System.out.println("Bloqueado pelo Trigger: " + e.getMessage());
                        }
                    }
                    case 0 -> System.out.println("Encerrando...");
                    default -> System.out.println("Opção inválida.");
                }
            } while (opcao != 0);
        } catch (SQLException e) {
            System.out.println("Erro de banco de dados: " + e.getMessage());
        }
    }

    private static String ler(Scanner s, String m) { System.out.print(m); return s.nextLine().trim(); }
    private static int lerInt(Scanner s, String m) { return Integer.parseInt(ler(s, m)); }
    private static int upd(Connection c, String q, Object... p) throws SQLException { try (PreparedStatement ps = c.prepareStatement(q)) { for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]); return ps.executeUpdate(); } }
    private static void call(Connection c, String q, Object... p) throws SQLException { try (CallableStatement cs = c.prepareCall(q)) { for (int i = 0; i < p.length; i++) cs.setObject(i + 1, p[i]); cs.execute(); } }

    private static void listar(Connection c) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement("SELECT id_aluno,nome,cpf,ativo FROM alunos ORDER BY id_aluno");
             ResultSet rs = ps.executeQuery()) {
            System.out.println("\n--- ALUNOS ---");
            while (rs.next())
                System.out.printf("ID: %d | Nome: %s | CPF: %s | Ativo: %b%n",
                        rs.getInt("id_aluno"), rs.getString("nome"), rs.getString("cpf"), rs.getBoolean("ativo"));
        }
    }
}
