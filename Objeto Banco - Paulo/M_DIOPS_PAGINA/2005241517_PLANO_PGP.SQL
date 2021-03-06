--<DS_SCRIPT>
-- DESCRI��O..: Criar tabela DBAPS.DIOPS_CONFIG_LINHA_PROCESSO
-- RESPONSAVEL: Paulo Gustavo
-- DATA.......: 28/04/2020
-- APLICA��O..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>

CREATE TABLE dbaps.diops_config_linha_processo (
  cd_diops_config_linha_processo NUMBER       NOT NULL,
  cd_diops_linha                 NUMBER       NOT NULL,
  cd_estrutural                  VARCHAR2(1000) NOT NULL,
  tp_filtro                      VARCHAR2(1) DEFAULT 'C' NOT NULL

)
  TABLESPACE sgps_d
/

CREATE INDEX dbaps.ind_diops_cfglinpro_cfgpg_1_fk
  ON dbaps.diops_config_linha_processo (
    cd_diops_linha
  )
  TABLESPACE sgps_i
/

CREATE INDEX dbaps.ind_diops_cfglinprocesso_1_fk
  ON dbaps.diops_config_linha_processo (
    cd_estrutural
  )
  TABLESPACE sgps_i
/

ALTER TABLE dbaps.diops_config_linha_processo
  ADD CONSTRAINT cnt_diops_cfg_linh_processo_pk PRIMARY KEY (
    cd_diops_config_linha_processo
  )
  USING INDEX TABLESPACE sgps_i
/

ALTER TABLE dbaps.diops_config_linha_processo
  ADD CONSTRAINT cnt_diops_cfglinpro_dlinh_1_fk FOREIGN KEY (
    cd_diops_linha
  ) REFERENCES dbaps.diops_linha (
    cd_diops_linha
  ) ON DELETE CASCADE
/

ALTER TABLE dbaps.diops_config_linha_processo
  ADD CONSTRAINT cnt_diops_config_linh_pro_1_ck CHECK (
    tp_filtro IN ('C', 'N')
  )
/

COMMENT ON TABLE dbaps.diops_config_linha_processo IS 'Configura��o das linhas por processo'
/
COMMENT ON COLUMN dbaps.diops_config_linha_processo.cd_diops_config_linha_processo IS 'Chave prim�ria'
/
COMMENT ON COLUMN dbaps.diops_config_linha_processo.cd_diops_linha IS 'Linha do DIOPS'
/
COMMENT ON COLUMN dbaps.diops_config_linha_processo.cd_estrutural IS 'C�digo estrutural do processo'
/
COMMENT ON COLUMN dbaps.diops_config_linha_processo.tp_filtro IS 'C-Contem o processo | N-N�o contem o processo'
/

GRANT DELETE,INSERT,SELECT,UPDATE ON dbaps.diops_config_linha_processo TO dbamv
/
GRANT DELETE,INSERT,REFERENCES,SELECT,UPDATE ON dbaps.diops_config_linha_processo TO dbasgu
/
GRANT DELETE,INSERT,SELECT,UPDATE ON dbaps.diops_config_linha_processo TO mv2000
/
GRANT DELETE,INSERT,SELECT,UPDATE ON dbaps.diops_config_linha_processo TO mvintegra
/

CREATE SEQUENCE dbaps.seq_diops_config_linha_process NOCACHE START WITH 1
/
GRANT SELECT ON dbaps.seq_diops_config_linha_process TO dbamv
/
GRANT SELECT ON dbaps.seq_diops_config_linha_process TO dbasgu
/
GRANT SELECT ON dbaps.seq_diops_config_linha_process TO mv2000
/
GRANT SELECT ON dbaps.seq_diops_config_linha_process TO mvintegra
/
