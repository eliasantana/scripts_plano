--<DS_SCRIPT>
-- DESCRIÇÃO..: Carga para a coluna DT_FIM_VIGENCIA na tabela TIPO_ATENDIMENTO_TISS
-- RESPONSAVEL: Elias Santana
-- DATA.......: 13/08/2020
-- APLICAÇÃO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>

DECLARE

    CURSOR cAtendimento IS
        SELECT
               cd_tipo_atendimento,
               cd_tiss,
               dt_fim_vigencia,
               To_Char(dt_inicio_vigencia, 'MM') mes,
               To_Char(SYSDATE, 'YYYY') ano
        FROM dbaps.tipo_atendimento_tiss;

    v_mes  VARCHAR2(2);
    v_ano  VARCHAR2(4);
    v_dia  NUMBER;
    v_data VARCHAR2(20);

BEGIN

    FOR r IN cAtendimento LOOP
        v_dia := r.cd_tiss;

        IF v_dia >30 THEN
            v_dia :=30;
        END IF;

        v_mes := Nvl(r.mes,1);
        v_ano := r.ano;
        v_data :=v_dia||'.'|| v_mes ||'.' ||v_ano;

        UPDATE dbaps.tipo_atendimento_tiss
        SET dt_fim_vigencia = TO_DATE(v_data,'dd.mm.yyyy')
        WHERE cd_tipo_atendimento=r.cd_tipo_atendimento;

    END LOOP;
    COMMIT;
END;
/