--<DS_SCRIPT>
-- DESCRI��O..: Exclus�o e recria��o da constraint para a coluna TP_TIP_PRESTADOR para aceitar o tipo 7 - OPME
-- RESPONSAVEL: Elias Santana da Silva
-- DATA.......: 22/07/2020
-- APLICA��O..: SOULMVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>


ALTER TABLE dbaps.tip_prestador DROP CONSTRAINT cnt_tip_prest_tp_tip_prest_ck;
/
ALTER TABLE dbaps.tip_prestador
  ADD CONSTRAINT cnt_tip_prest_tp_tip_prest_ck CHECK (
    TP_TIP_PRESTADOR IN ('1', '2', '3', '4', '5', '6','7')
  )
/
COMMENT ON COLUMN dbaps.tip_prestador.tp_tip_prestador IS 'TIPO DE TIP_PRESTADOR (1 - M�DICO, 2 - CL�NICA, 3 - LABORAT�RIO, 4 - HOSPITAL, 5 - OUTROS, 6 - COOPERADO,   7 - OPME)';
/





