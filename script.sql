CREATE TABLE alunos (id_aluno SERIAL PRIMARY KEY, nome VARCHAR(120) NOT NULL, cpf VARCHAR(14) NOT NULL UNIQUE, data_cadastro DATE NOT NULL DEFAULT CURRENT_DATE, ativo BOOLEAN NOT NULL DEFAULT TRUE);

CREATE TABLE planos (id_plano SERIAL PRIMARY KEY, nome VARCHAR(80) NOT NULL UNIQUE, duracao_dias INTEGER NOT NULL CHECK (duracao_dias > 0), valor NUMERIC(10,2) NOT NULL CHECK (valor > 0));

CREATE TABLE matriculas (id_matricula SERIAL PRIMARY KEY, id_aluno INTEGER NOT NULL REFERENCES alunos(id_aluno), id_plano INTEGER NOT NULL REFERENCES planos(id_plano), data_inicio DATE NOT NULL DEFAULT CURRENT_DATE, data_fim DATE NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'ATIVA' CHECK (status IN ('ATIVA','VENCIDA','BLOQUEADA')), CONSTRAINT chk_datas_matricula CHECK (data_fim >= data_inicio));

CREATE TABLE pagamentos (id_pagamento SERIAL PRIMARY KEY, id_matricula INTEGER NOT NULL REFERENCES matriculas(id_matricula), valor_pago NUMERIC(10,2) NOT NULL CHECK (valor_pago > 0), data_pagamento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, forma_pagamento VARCHAR(30) NOT NULL CHECK (forma_pagamento IN ('PIX','DINHEIRO','CARTAO')));

CREATE TABLE checkins (id_checkin SERIAL PRIMARY KEY, id_aluno INTEGER NOT NULL REFERENCES alunos(id_aluno), data_hora_entrada TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP);

CREATE OR REPLACE FUNCTION fn_dias_restantes_matricula(p_id_aluno INTEGER)
RETURNS INTEGER LANGUAGE sql AS $$
    SELECT COALESCE((
        SELECT CASE WHEN status='ATIVA' AND data_fim >= CURRENT_DATE
                    THEN data_fim - CURRENT_DATE ELSE 0 END
        FROM matriculas WHERE id_aluno=p_id_aluno
        ORDER BY data_fim DESC, id_matricula DESC LIMIT 1
    ), 0);
$$;

CREATE OR REPLACE PROCEDURE sp_matricular_ou_renovar(
    p_id_aluno INTEGER, p_id_plano INTEGER, p_valor_pago NUMERIC(10,2), p_forma_pagamento VARCHAR(30)
)
LANGUAGE plpgsql AS $$
DECLARE v_ativo BOOLEAN; v_duracao INTEGER; v_valor_plano NUMERIC(10,2); v_dias INTEGER; v_id INTEGER;
BEGIN
    SELECT ativo INTO v_ativo FROM alunos WHERE id_aluno=p_id_aluno;
    IF NOT FOUND OR NOT v_ativo THEN RAISE EXCEPTION 'Aluno % inexistente ou inativo.', p_id_aluno; END IF;
    SELECT duracao_dias, valor INTO v_duracao, v_valor_plano FROM planos WHERE id_plano=p_id_plano;
    IF NOT FOUND THEN RAISE EXCEPTION 'Plano % inexistente.', p_id_plano; END IF;
    IF p_valor_pago < v_valor_plano THEN RAISE EXCEPTION 'Valor pago (%) inferior ao valor do plano (%).', p_valor_pago, v_valor_plano; END IF;
    v_dias := fn_dias_restantes_matricula(p_id_aluno);
    INSERT INTO matriculas (id_aluno,id_plano,data_inicio,data_fim,status)
    VALUES (p_id_aluno,p_id_plano,CURRENT_DATE,CURRENT_DATE+v_duracao+CASE WHEN v_dias>0 THEN v_dias ELSE 0 END,'ATIVA')
    RETURNING id_matricula INTO v_id;
    INSERT INTO pagamentos (id_matricula,valor_pago,forma_pagamento)
    VALUES (v_id,p_valor_pago,p_forma_pagamento);
    COMMIT;
END;
$$;

CREATE OR REPLACE FUNCTION fn_valida_checkin() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF fn_dias_restantes_matricula(NEW.id_aluno) <= 0 THEN
        RAISE EXCEPTION 'Check-in negado: aluno % sem matricula ativa ou com dias restantes zerados.', NEW.id_aluno;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_valida_checkin_antes_insert
BEFORE INSERT ON checkins FOR EACH ROW EXECUTE FUNCTION fn_valida_checkin();
