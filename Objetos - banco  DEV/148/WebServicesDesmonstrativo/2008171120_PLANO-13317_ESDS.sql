--<DS_SCRIPT>
-- DESCRICAO..: Criação de chave TISS_SENHA_UNIMED
-- RESPONSAVEL: Elias Silva
-- DATA.......: 17/08/2020
-- APLICAÃ‡ÃƒO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>


BEGIN
  FOR rMultiEmpresa IN (SELECT CD_MULTI_EMPRESA FROM DBAMV.MULTI_EMPRESAS_MV_SAUDE)
  LOOP
    INSERT INTO DBAPS.MVS_CONFIGURACAO (cd_multi_empresa
                                       , ds_configuracao
                                       , chave
                                       , valor
									   , TP_TIPO)
      VALUES ( rMultiEmpresa.cd_multi_empresa,
               'SENHA DE ACESSO AOS WEBSERVICES TISS PARA UNIMED BRASIL',
               'TISS_SENHA_UNIMED',
               'bfa3bb6edee6cde8de71aa93f8e829b4',
			   'V'
             );
	COMMIT;

  END LOOP;

  COMMIT;

END;
/