PROMPT CREATE OR REPLACE TRIGGER dbaps.trg_mvs_configuracao
CREATE OR REPLACE TRIGGER dbaps.trg_mvs_configuracao
BEFORE INSERT  OR DELETE  OR UPDATE
ON dbaps.mvs_configuracao
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

  /**************************************************************
    <objeto>
     <nome>trg_mvs_configuracao</nome>
     <usuario>Elias Silva</usuario>
     <alteracao>18/08/2020 09:45</alteracao>
     <descricao>VALIDAÇÃO DA CHAVE TISS_SENHA_UNIMED </descricao>
     <ultimaAlteracao>
               - Adicionado validação para a chave TISS_SENHA_UNIMED
               - Adicionado conversão para Hash MD5 no campo valor
     </ultimaAlteracao>
     <parametro></parametro>
     <versao>1.52</versao>
     <soul>PLANO-13317</soul>
    </objeto>
  ***************************************************************/

DECLARE

  vMsgValorSN VARCHAR2(1000);
  vMsgValorVazio VARCHAR2(1000);

 /**
  * Function que valida se uma query retorna linhas maior que 0
  */
 FUNCTION FNC_VALIDACAO_TABELA(pQuery IN VARCHAR2) RETURN Varchar2 IS
    vTotal NUMBER;
    type tpTeste is REF CURSOR;
    cCursorTeste tpTeste;

  BEGIN

    vTotal := 0;

    open cCursorTeste FOR pQuery;
    fetch cCursorTeste
      into vTotal;
    CLOSE cCursorTeste;

    IF vTotal = 0 THEN
      RETURN 'N';
    ELSE
      RETURN 'S';
    END IF;

  END;

BEGIN

  vMsgValorSN := 'Valor n?o permitido, apenas os valores S ou N s?o aceitos (Letras Maiusculas)';
  vMsgValorVazio := 'Valor da chave n?o pode ser vazio!';

  --***************************************************************************
  --* CHAVES DO TIPO 'S' OU 'N'
  --***************************************************************************
  IF  --TISS
      :NEW.CHAVE = 'WEBSERVICE_STATUS_AUTORIZACAO'   OR
      :NEW.CHAVE = 'WEBSERVICE_CANCELA_GUIA'         OR
      :NEW.CHAVE = 'WEBSERVICE_COMUNICACAO_BENEF'    OR
      :NEW.CHAVE = 'WEBSERVICE_LOTE_GUIA'            OR
      :NEW.CHAVE = 'WEBSERVICE_SOLIC_PROCEDIMENTO'   OR
      :NEW.CHAVE = 'WEBSERVICE_VALIDA_LOGIN_SENHA'   OR
      :NEW.CHAVE = 'WEBSERVICE_RECURSO_GLOSA'        OR
      :NEW.CHAVE = 'WEBSERVICE_STATUS_PROTOCOLO'     OR
      :NEW.CHAVE = 'WEBSERVICE_STATUS_REC_GLOSA'     OR
      :NEW.CHAVE = 'WEBSERVICE_VERIFICA_ELEGIB'      OR
      :NEW.CHAVE = 'WEBSERVICE_SIT_PROTO_AUDITADA'   OR
      :NEW.CHAVE = 'WEBSERVICE_SENHA_MD5'            OR
      :NEW.CHAVE = 'WEBSERVICE_STATUS_AUTORIZACAO'   OR
      :NEW.CHAVE = 'WEBSERVICE_DEMONST_RETORNO'      OR
      :NEW.CHAVE = 'TISS_CARTEIRA_SOMENTE_NUMEROS'   OR
      :NEW.CHAVE = 'ATEND_GUIA_ODONTO_EXIB_VALOR'    OR
      :NEW.CHAVE = 'TISS_PESQUISA_PELA_CARTEIRA'     OR
      :NEW.CHAVE = 'ANS_MONIT_PROCED_PACOTE'         OR
      --PTU
      :NEW.CHAVE = 'WEBSERVICE_PTU_RESP_AUDITORIA'   OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_AUTORIZACAO'      OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_CANCELAMENTO'     OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_ORDEM_SERVICO'    OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_CONS_DADO_BENEF'  OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_DECURSO_PRAZO'    OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_CONS_DADO_PREST'  OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_INSISTENCIA'      OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_STAT_TRANSACAO'   OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_COMPLEMENTO_AUT'  OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_AUT_ORD_SERVICO'  OR
      :NEW.CHAVE = 'WEBSERVICE_PTU_CONT_BENEF'       OR
      :NEW.CHAVE = 'PTU_BATCH_VALIDA_A500_AVISO'     OR
      --PORTAL
      :NEW.CHAVE = 'PORTAL_INCBENEF_OBRIGA_EMAIL'    OR
      :NEW.CHAVE = 'PORTAL_INCBENEF_OBRIGA_TEL'      OR
      :NEW.CHAVE = 'PORTAL_INCBENEF_TIT_OBG_CATEG'   OR
      :NEW.CHAVE = 'PORTAL_MENU_ALT_DADOS_CADASTRO'  OR
      :NEW.CHAVE = 'PORTAL_MENU_CONS_SOLICITACOES'   OR
      :NEW.CHAVE = 'PORTAL_MENU_REEMBOLSO'           OR
      :NEW.CHAVE = 'PORTAL_MENU_SOLIC_REEMBOLSO'     OR
      :NEW.CHAVE = 'PORTAL_REC_SENHA_TLS'            OR
      :NEW.CHAVE = 'PORTAL_SN_DOC_OBRIGA_SOLIC_WEB'  OR
      :NEW.CHAVE = 'PORTAL_SN_DOC_OBRIGA_TERMO'      OR
      :NEW.CHAVE = 'SN_DOC_OBRIGATORIOS_MIGRACAO'    OR
      :NEW.CHAVE = 'PORTAL_MENU_SOLIC_REEMBOLSO'     OR
      :NEW.CHAVE = 'PORTAL_MENU_SOLIC_REEMBOLSO'     OR
      :NEW.CHAVE = 'PORTAL_MENU_SOLIC_REEMBOLSO'     OR
      :NEW.CHAVE = 'PORTAL_MENU_SOLIC_REEMBOLSO'     OR
      :NEW.CHAVE = 'PORTAL_MENU_SOLIC_REEMBOLSO'     OR
      :NEW.CHAVE = 'PORTAL_INCBENEF_OBRIGA_CEL'      OR
      :NEW.CHAVE = 'PORTAL_SN_OBRIGA_CDCALLCENTER'   OR
      :NEW.CHAVE = 'PORTAL_SN_MENU_CALL_CENTER'      OR
      :NEW.CHAVE = 'PORTAL_SN_MENU_REATIVA_BENEFIC'  OR
      :NEW.CHAVE = 'PORTAL_SN_MENU_DOCUMENTOS'       OR
      :NEW.CHAVE = 'PORTAL_SN_INIBIR_DS_PROCED'      OR
      :NEW.CHAVE = 'PORTAL_SN_MENU_IMPORTA_ARQUIVO'  OR
      :NEW.CHAVE = 'PORTAL_SN_VALIDAR_XMLLOTETISS'   OR
      --FATURAMENTO
      :NEW.CHAVE = 'SN_CNAB240_SANTADER'             OR
      :NEW.CHAVE = 'SN_BAIXA_NOSSO_NUMERO_DIGITO'    OR
      :NEW.CHAVE = 'SN_BOLETO_EXIBE_ENDERECO'        OR
      :NEW.CHAVE = 'SN_BOLETO_EXIBE_FOLHA_CAPA'      OR
      :NEW.CHAVE = 'SN_BOLETO_EXIBE_RECEB_CHEQUE'    OR
      :NEW.CHAVE = 'SN_VALOR_COBRADO'                OR
      :NEW.CHAVE = 'SN_MSG_CONTA_CORRENTE'           OR
      :NEW.CHAVE = 'SN_PRIMEIRA_MENSALIDADE_PAGA'    OR
      :NEW.CHAVE = 'SN_UTILIZA_MES_BASE'             OR
      :NEW.CHAVE = 'FAT_FIX_IDADE_PLANOS_ANTES_LEI'  OR
      :NEW.CHAVE = 'FAT_MSG_PROTOC_AUTORIZACAO'      OR
      :NEW.CHAVE = 'SN_CALCULA_VALOR_PROPORCIONAL'   OR
      :NEW.CHAVE = 'FAT_SEGUE_DT_CONT_PAI_RESP_COB'  OR
      :NEW.CHAVE = 'FAT_IMP_COB_REV_REL_DET_FAT'     OR
      --CONTAS MEDICAS
      :NEW.CHAVE = 'CONTMED_IMP_EQP_CORPO_CLINICO'   OR
      :NEW.CHAVE = 'SN_IMPRIME_PROCED_PRESTADOR'     OR
      :NEW.CHAVE = 'CONTMED_GLOSA_MATINVAL_FATURA'   OR
      :NEW.CHAVE = 'CONTMED_AUDITAR_PROTOCOLO'       OR
      :NEW.CHAVE = 'CONTMED_GLOSA_AUTOMATICA'        OR
      :NEW.CHAVE = 'CONTMED_IMP_XML_NORMALIZADO'     OR
      :NEW.CHAVE = 'CONTMED_PAGTO_UNIFICADO'         OR
      :NEW.CHAVE = 'CONTMED_IMP_GUIA_DT_REA_PROC'    OR
      :NEW.CHAVE = 'CONTMED_TP_LOCK'                 OR
      :NEW.CHAVE = 'CONTMED_FOLHA_VENCIMENTO_RETRO'  OR
      :NEW.CHAVE = 'CONTMED_IMPORTAR_VALOR_TOT_XML'  OR
      :NEW.CHAVE = 'CONTMED_COBRANCA_INTERCAMBIO'    OR
      :NEW.CHAVE = 'CONTMED_VIA_ACESSO_COM_REDUTOR'  OR
      :NEW.CHAVE = 'CONTMED_PRESTADOR_COBRANCA_PTU'  OR
      :NEW.CHAVE = 'CONTMED_FOLHA_REPASSE_NF'        OR
      :NEW.CHAVE = 'CONTMED_DIARIA_INTER_ESTADUAL'   OR
      :NEW.CHAVE = 'CONTMED_EDIT_VLCOB_REVERT'       OR
      :NEW.CHAVE = 'CONTMED_PAG_PERC_FI'             OR
      :NEW.CHAVE = 'CONTMED_PAG_PERC_CO'             OR
      :NEW.CHAVE = 'CONTMED_COB_PERC_FI'             OR
      :NEW.CHAVE = 'CONTMED_COB_PERC_CO'             OR
      :NEW.CHAVE = 'CONTMED_IMPXML_SENHA_GUIPREST'   OR
      :NEW.CHAVE = 'CONTMED_CUSTO_OP_CONCOMITANTE'   OR
      :NEW.CHAVE = 'CONTMED_DT_ENTRADA_FRANQ_HOSP'   OR
      :NEW.CHAVE = 'CONTMED_EDIT_VLCOB_REVERT_ZERO'  OR
      :NEW.CHAVE = 'CONTMED_TELA_VL_COB_AUTOMATICO'  OR
      :NEW.CHAVE = 'CONTMED_FILTRA_ESPEC_PROF_EXEC'  OR
      :NEW.CHAVE = 'CONTMED_EXIB_CAMP_POR_TIP_GUIA'  OR
      :NEW.CHAVE = 'CONTMED_DT_LCTO_REGRA_ERP'       OR
      :NEW.CHAVE = 'CONTMED_QUEBRA_VALOR_RECALCULO'  OR
      :NEW.CHAVE = 'CONTMED_TXADMIN_PRAZO_EXPIRADO'  OR
      :NEW.CHAVE = 'CONTMED_REGRA_PRESTADOR_COOP'    OR
      :NEW.CHAVE = 'CONTMED_ALTERA_VALOR_COB'        OR
      :NEW.CHAVE = 'CONTMED_ALTERA_VALOR_COB_PTU'    OR
      :NEW.CHAVE = 'CONTMED_PERMITE_EXCLUIR_CM'      OR
      :NEW.CHAVE = 'CONTMED_ACEITA_PERC_PRESTADOR'   OR
      :NEW.CHAVE = 'CONTMED_VALOR_PAGO_MAIOR_CM'     OR
      :NEW.CHAVE = 'CONTMED_ALTERA_VALOR_PAG'        OR
      :NEW.CHAVE = 'CONTMED_ALTERA_VALOR_PAG_PTU'    OR
      :NEW.CHAVE = 'CONTMED_IMPORTA_AUDITOR_AUT'     OR
      :NEW.CHAVE = 'CONTMED_FATOR_URGENCIA_CBHPM'    OR
      :NEW.CHAVE = 'CONTMED_SN_ALTERA_VALOR_PAGO'    OR
      :NEW.CHAVE = 'CONTMED_OBRIGA_GLOSA_PARCIAL'    OR
      :NEW.CHAVE = 'CONTMED_APLICA_TAXA_SAUDE_OCUP'  OR
      :NEW.CHAVE = 'CONTMED_ACOMODACAO_BENEF_CRIT'   OR
      :NEW.CHAVE = 'CONTMED_XML_FUN_PROC_EQP_GP'     OR
      :NEW.CHAVE = 'CONTMED_MUDA_GLOSA_DUPLICIDADE'  OR
      :NEW.CHAVE = 'CONTMED_CALC_ACOMODACAO_CO_FI'   OR
      --ATENDIMENTO
      :NEW.CHAVE = 'ELEG_VERIF_AGEND_DESLIGAMENTO'   OR
      :NEW.CHAVE = 'DISABLE_BTN_VISUALIZAR'          OR
      :NEW.CHAVE = 'SN_APARECER_TELEFONE_OBS_GUIA'   OR
      :NEW.CHAVE = 'SN_EXIBI_MATRI_ALTER_GUIA_TISS'  OR
      :NEW.CHAVE = 'SN_EXIGE_GUIA_INTERNACAO_HONOR'  OR
      :NEW.CHAVE = 'SN_VERIFICAR_DE_PARA_GUIA'       OR
      :NEW.CHAVE = 'ATEND_SN_MSG_PROC_ROL_ANS'       OR
      :NEW.CHAVE = 'REEMB_FORNC_LISTA_TODOS'         OR
      --CALL CENTER
      :NEW.CHAVE = 'DISABLE_BTNS_CALL_CENTER'        OR
      :NEW.CHAVE = 'CALL_CENTER_DT_INICIO_TRAMITE'   OR
      --FOLHA
      :NEW.CHAVE = 'SN_GERAR_MATRICULA_SASSEPE'      OR
      --ANS
      :NEW.CHAVE = 'SN_ENVIAR_CNPJ_EMPRESA_SIB'      OR
      -- AUTORIZADOR WEB
      :NEW.CHAVE = 'AUTWEB_SN_MENU_LOTE_GUIAS'       OR
      --IMPLANTACAO
      :NEW.CHAVE = 'CONFIG_MODO_IMPLANTACAO'         OR
      -- CADASTRO
      :NEW.CHAVE = 'CAD_DESLIG_REAT_TIT_CONTRATO'    OR
      :NEW.CHAVE = 'CAD_MANT_CONT_ATIVO'             OR
      -- CREDENCIAMENTO
      :NEW.CHAVE = 'CREDENCIA_SN_REMOVE_REGRA_PGTO'	 OR
			-- CARTEIRA
			:NEW.CHAVE = 'SN_UTILIZA_FNC_GERAR_CARTEIRA'   OR
      -- CONFIGURACAO GERAL
      :NEW.CHAVE = 'CONFIG_HABILITA_PONTO_ENTRADA'   OR
      :NEW.CHAVE = 'CONFIG_IMPOSTO_PF_UNICO'
   THEN

      -- VERIFICANDO SE CHAVE E VAZIA
      IF :NEW.VALOR IS NULL THEN
        Raise_Application_Error(-20000, vMsgValorVazio);
      END IF;

      -- VERIFICANDO SE VALOR E S OU N
      IF (:NEW.VALOR <> 'S' AND :NEW.VALOR <> 'N') THEN
        Raise_Application_Error(-20000, vMsgValorSN);
      END IF;

   END IF;

  --***************************************************************************
  --* CHAVES DO MODULO CONTAS MEDICAS
  --***************************************************************************
  IF :NEW.VALOR IS NOT NULL AND :NEW.CHAVE = 'CONTMED_ATIMED_PADRAO' THEN
    IF FNC_VALIDACAO_TABELA('SELECT 1 FROM DBAPS.ATI_MED WHERE CD_ATI_MED ='||:NEW.VALOR) = 'N' THEN
       Raise_Application_Error(-20001, 'Codigo de atividade medica invalido! Verifique os valores possiveis na tela de Atividades Medicas');
    END IF;
  END IF;

  IF :NEW.VALOR IS NOT NULL AND :NEW.CHAVE = 'CONTMED_GLOSA_MATINVALIDA' THEN
    IF FNC_VALIDACAO_TABELA('SELECT 1 FROM DBAPS.MOTIVO_GLOSA WHERE CD_MOTIVO = '||:NEW.VALOR) = 'N' THEN
       Raise_Application_Error(-20001, 'Codigo de motivo de glosa invalido! Verifique os valores possiveis na tela de Motivo de Glosa');
    END IF;
  END IF;

  --***************************************************************************
  --* CHAVES DO MODULO FATURAMENTO
  --***************************************************************************

  --***************************************************************************
  --* CHAVES DO MODULO PTU BATCH
  --***************************************************************************
  IF :NEW.CHAVE = 'PTU_BATCH_A580_DOC_FISCAL' THEN
    -- VERIFICANDO SE CHAVE E VAZIA
      IF :NEW.VALOR IS NULL THEN
        Raise_Application_Error(-20000, vMsgValorVazio);
      END IF;

      -- VERIFICANDO SE VALOR E NF (NFE) OU MC (MENS_CONTRATO)
      IF (:NEW.VALOR <> 'NF' AND :NEW.VALOR <> 'MC') THEN
        Raise_Application_Error(-20000, 'Valor n?o permitido, apenas os valores NF ou MC s?o aceitos (Letras Maiusculas)');
      END IF;
  END IF;

  --***************************************************************************
  --* CHAVES DO MODULO GERAL
  --***************************************************************************
  IF :NEW.CHAVE = 'CONFIG_MAIL_ALERT_AGEND_DESLIG' THEN
    IF REGEXP_SUBSTR (:NEW.VALOR, '[a-zA-Z0-9._%-]+@[a-zA-Z0-9._%-]+\.[a-zA-Z]{2,4}') IS NULL THEN
      Raise_Application_Error(-20001, 'E-mail invalido, favor verificar');
    END IF;
  END IF;

  --***************************************************************************
  --* CHAVES DO AUTORIZADORWEB
  --***************************************************************************
  IF :NEW.CHAVE = 'AUTWEB_LINK_FOOTER_TABELA_TUSS'  OR
     :NEW.CHAVE = 'AUTWEB_LINK_FOOTER_MANUAL_MV'    OR
     :NEW.CHAVE = 'AUTWEB_LINK_FOOTER_VIDEO_AULA'   OR
     :NEW.CHAVE = 'AUTWEB_LINK_FOOTER_PROTOCOLOS'   THEN
    NULL;
  END IF;

  --***************************************************************************
  --* CHAVES DO MODULO TISS
  --***************************************************************************
  IF :NEW.CHAVE = 'TISS_CAMPO_SIB_MATRICULA' THEN
    -- VERIFICANDO SE CHAVE E VAZIA
      IF :NEW.VALOR IS NULL THEN
        Raise_Application_Error(-20000, vMsgValorVazio);
      END IF;

      -- VERIFICANDO SE VALOR E CD_MATRICULA OU CD_MAT_ALTERNATIVA
      IF (:NEW.VALOR <> 'CD_MATRICULA' AND :NEW.VALOR <> 'CD_MAT_ALTERNATIVA') THEN
        Raise_Application_Error(-20000, 'Valor n?o permitido, apenas os valores CD_MATRICULA ou CD_MAT_ALTERNATIVA s?o aceitos (Letras Maiusculas)');
      END IF;
  END IF;

  IF Nvl(:NEW.CHAVE, :OLD.CHAVE) = 'FAT_EDITAR_DT_CREDITO' AND NOT DELETING THEN
    IF Nvl(:NEW.VALOR, :OLD.VALOR) IS NULL OR Nvl(:NEW.VALOR, :OLD.VALOR) NOT IN ('S', 'N') THEN
      Raise_Application_Error(-20001, 'Valor da chave FAT_EDITAR_DT_CREDITO deve ser S ou N.');
    END IF;
  END IF;

  IF Nvl(:NEW.CHAVE, :OLD.CHAVE) = 'ANS_QTD_MESES_ANALISE_RPC' THEN
    IF :NEW.VALOR IS NULL THEN
      Raise_Application_Error(-20000, vMsgValorVazio);
    END IF;
    IF To_Number(REGEXP_REPLACE(:NEW.VALOR, '[^0-9]')) > 12 THEN
      Raise_Application_Error(-20001, 'Valor da chave n?o pode ser menor que 12 meses.');
    END IF;

  END IF;

  -- VERIFICA E CALCULA HASH MD5 PARA VALOR SE DIFERENTE DE NULO

  IF INSERTING THEN
    IF :NEW.CHAVE = 'TISS_SENHA_UNIMED' THEN

      IF  :NEW.VALOR IS NULL THEN
          Raise_Application_Error(-20000, vMsgValorVazio);
      END IF;

      BEGIN
          :NEW.VALOR := dbaps.fnc_calcula_md5(:NEW.VALOR);
      END;

    END IF;
  END IF;

END;
/

