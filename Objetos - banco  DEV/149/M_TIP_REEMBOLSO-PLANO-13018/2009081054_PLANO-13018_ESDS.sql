--<DS_SCRIPT>
-- DESCRIÇÃO..: Adicionando colunas para controle e selecao dos tipos de reembolso.
-- RESPONSAVEL: Elias Santana
-- DATA.......: 08/09/2020
-- APLICAÇÃO..: MVSAUDE
--</DS_SCRIPT>
--<USUARIO=DBAPS>

ALTER TABLE dbaps.tipo_reembolso DISABLE ALL TRIGGERS
/
ALTER TABLE  dbaps.tipo_reembolso ADD SN_ENVIO_DMED VARCHAR2(1)
/
UPDATE dbaps.tipo_reembolso SET SN_ENVIO_DMED = 'S'
/
ALTER TABLE  dbaps.tipo_reembolso ADD SN_ENVIO_SIP VARCHAR2(1)
/
UPDATE dbaps.tipo_reembolso SET SN_ENVIO_SIP ='S'
/
ALTER TABLE  dbaps.tipo_reembolso ADD SN_ENVIO_MONIT_TISS VARCHAR2(1)
/
UPDATE dbaps.tipo_reembolso SET SN_ENVIO_MONIT_TISS='S'
/
COMMIT
/
ALTER TABLE dbaps.tipo_reembolso MODIFY SN_ENVIO_DMED DEFAULT 'S' NOT NULL
/
ALTER TABLE dbaps.tipo_reembolso MODIFY SN_ENVIO_SIP DEFAULT 'S' NOT NULL
/
ALTER TABLE dbaps.tipo_reembolso MODIFY SN_ENVIO_MONIT_TISS DEFAULT 'S' NOT NULL
/

ALTER TABLE dbaps.tipo_reembolso
    ADD CONSTRAINT cnt_sn_envio_dmed_chk  CHECK (
      SN_ENVIO_DMED IN ('S','N')
    )
/
ALTER TABLE dbaps.tipo_reembolso
    ADD CONSTRAINT cnt_sn_envio_sip_chk CHECK (
     SN_ENVIO_SIP IN ('S','N')
   )

/
ALTER TABLE dbaps.tipo_reembolso
  ADD CONSTRAINT cnt_sn_envio_monit_tiss_chk CHECK (
    SN_ENVIO_MONIT_TISS IN ('S','N')
  )
/
ALTER TABLE dbaps.tipo_reembolso ENABLE  ALL TRIGGERS
/
COMMENT ON COLUMN dbaps.tipo_reembolso.SN_ENVIO_DMED IS 'Controle de Envio DMED'
/
COMMENT ON COLUMN dbaps.tipo_reembolso.SN_ENVIO_SIP IS 'Controle de Envio SIP'
/
COMMENT ON COLUMN dbaps.tipo_reembolso.SN_ENVIO_MONIT_TISS IS 'Controle Monitorramento TISS'
/