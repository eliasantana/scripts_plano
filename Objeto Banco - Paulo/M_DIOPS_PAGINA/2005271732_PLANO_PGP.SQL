--<DS_SCRIPT>
-- DESCRIÇÃO..: Relacionar DBAPS.DIOPS_CONFIG_LINHA com
-- DBAPS.DIOPS_CONFIG_LINHA_PROCESSO
-- RESPONSAVEL: Paulo Gustavo
-- DATA.......: 28/04/2020
-- APLICAÇÃO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>

ALTER TABLE dbaps.diops_config_linha_processo add
  cd_diops_config_linha NUMBER
/

CREATE INDEX dbaps.ind_diops_cfglinpro_cfdli_1_fk
  ON dbaps.diops_config_linha_processo (
    cd_diops_config_linha
  )
  TABLESPACE sgps_i
/

ALTER TABLE dbaps.diops_config_linha_processo
  ADD CONSTRAINT cnt_diops_cfglinpro_cfdli_1_fk FOREIGN KEY (
    cd_diops_config_linha
  ) REFERENCES dbaps.diops_config_linha (
    cd_diops_config_linha
  ) ON DELETE CASCADE
/
COMMENT ON COLUMN dbaps.diops_config_linha_processo.cd_diops_config_linha IS 'Configuração da linha do DIOPS'
/