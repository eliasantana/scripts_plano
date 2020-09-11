--<DS_SCRIPT>
-- DESCRI��O..: Criando coluna DT_FIM_VIGENCIA para permitir filtragem do procedimento na tela de GUIA
-- RESPONSAVEL: Elias Santana
-- DATA.......: 13/08/2020
-- APLICA��O..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>

ALTER TABLE DBAPS.TIPO_ATENDIMENTO_TISS ADD DT_FIM_VIGENCIA DATE
/
COMMENT ON COLUMN DBAPS.TIPO_ATENDIMENTO_TISS.DT_FIM_VIGENCIA IS 'Data final de vig�ncia do tipo de atendimento'
/

