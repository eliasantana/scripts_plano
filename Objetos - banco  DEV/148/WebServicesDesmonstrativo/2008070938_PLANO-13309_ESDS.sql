--<DS_SCRIPT>
-- DESCRIÇÃO..: Alteracao no tamanho das colunas para comportar faturas com codigos maior que cinco digitos.
-- RESPONSAVEL: Elias Santana
-- DATA.......: 07/08/2020
-- APLICAÇÃO..: MVSAUDE
--</DS_SCRIPT>
--<USUARIO=DBAPS>


ALTER TABLE dbaps.fatura  MODIFY cd_fatura NUMBER(20,0)
/
ALTER TABLE dbaps.lote MODIFY cd_fatura NUMBER(20,0)
/
ALTER TABLE dbaps.pagamento_prestador MODIFY cd_fatura VARCHAR2(4000)
/
ALTER TABLE dbaps.recurso_glosa MODIFY cd_fatura NUMBER(20,0)
/
ALTER TABLE dbaps.calendario_conta_automatico MODIFY cd_fatura NUMBER(20,0)
/