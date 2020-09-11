--<DS_SCRIPT>
-- DESCRIÇÃO..: Validação para login especifico da unimed brasil
-- RESPONSAVEL: Elias Silva
-- DATA.......: 03/09/2020
-- APLICAÇÃO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>

CREATE OR REPLACE PROCEDURE dbaps.prc_tiss_valida_cabecalho(P_ID_TISS_MENSAGEM IN NUMBER,
                                                            P_CD_PRESTADOR_OPERADORA OUT NUMBER,
                                                            P_NR_REGISTRO_ANS OUT NUMBER,
                                                            P_CD_MULTI_EMPRESA OUT NUMBER,
                                                            P_NR_CNPJ_OPERADORA OUT VARCHAR2,
                                                            P_DS_OPERADORA OUT VARCHAR2,
                                                            P_CD_GLOSA OUT VARCHAR2,
                                                            P_DS_GLOSA OUT VARCHAR2) IS

   /**************************************************************
    <objeto>
     <nome>prc_tiss_valida_cabecalho</nome>
     <usuario>Pedrinaldino Silva</usuario>
     <alteracao>02/09/2020 08:00</alteracao>
     <ultimaAlteracao>Adicionada a versao tiss 3.05.00</ultimaAlteracao>
     <descricao>procedure chamada por todos os webservices para validar dados do
                     cabecalho de qualquer mensagem TISS. Retorna dados necessarios
                     para montar a mensagem de resposta.
    - codigo de prestador na operadora (a partir do codigo, CNPJ ou CPF)
              - registro ans da operadora, codigo multi_empresa da operadora
              - cnpj da operadora (versao 2.2.3), descricao da operadora
              - codigo da glosa, descricao da glosa
     </descricao>
     <parametro></parametro>
     <tags>guia, importacao, xml</tags>
     <versao>1.10</versao>
    </objeto>
  ***************************************************************/

  /* Cursor que busca a requisic?o tiss_mensagem */
  CURSOR cTissMensagem IS
    SELECT TM.NR_REGISTRO_ANS_DESTINO
          ,NVL(TM.NR_CNPJ_PRESTADOR_OPERADORA, TM.NR_CPF_PRESTADOR_OPERADORA) NR_CNPJCPF_PRESTADOR
          ,TM.CD_PRESTADOR_OPERADORA
          ,TM.CD_VERSAO
          ,CASE
             WHEN TM.CD_VERSAO <= '2.01.03' THEN
              NVL(TO_DATE(TM.DT_TRANSACAO || ' ' || SubStr(TM.HR_TRANSACAO, 1, 8), 'DD/MM/YYYY HH24:MI'), SYSDATE)
             ELSE
              NVL(TO_DATE(TM.DT_TRANSACAO || ' ' || SubStr(TM.HR_TRANSACAO, 1, 8), 'YYYY-MM-DD HH24:MI:SS'), SYSDATE)
           END DT_TRANSACAO,
           TM.NR_CNPJ_PAGADOR_DESTINO,
           TM.DS_LOGIN_PRESTADOR,
           TM.DS_SENHA_PRESTADOR,
           TM.NR_WS_IP_REMETENTE,
           TM.NR_REGISTRO_ANS_ORIGEM
      FROM DBAPS.TISS_MENSAGEM TM
     WHERE TM.ID = P_ID_TISS_MENSAGEM;

  /**
   * Identificar a MultiEmpresa a partir do registro ANS ou CNPJ
   */
  CURSOR cPlanoDeSaude(PNR_ANS IN NUMBER, PNR_CGC IN NUMBER) IS
    SELECT ME_MVS.NR_ANS, ME.DS_MULTI_EMPRESA, ME.CD_CGC, ME_MVS.CD_MULTI_EMPRESA
      FROM DBAMV.MULTI_EMPRESAS_MV_SAUDE ME_MVS, DBAMV.MULTI_EMPRESAS ME
     WHERE (ME_MVS.NR_ANS = PNR_ANS OR ME.CD_CGC = PNR_CGC)
       AND ME_MVS.CD_MULTI_EMPRESA = ME.CD_MULTI_EMPRESA;

  /**
   * Identifica o prestador a partir de um codigo, cnpj ou cpf
   */
  CURSOR cPrestador(PCD_PRESTADOR IN NUMBER, PNR_CNPJCPF IN VARCHAR, P_CD_MULTI_EMPRESA IN NUMBER, NR_REGISTRO_ANS IN VARCHAR ) IS
    SELECT PRESTADOR.CD_PRESTADOR
          ,PRESTADOR.NR_CPF_CGC
          ,PRESTADOR.TP_PRESTADOR
          ,PRESTADOR.NM_PRESTADOR
          ,PRESTADOR.DS_ENDERECO
          ,PRESTADOR.NR_ENDERECO
          ,PRESTADOR.DS_COMPLEMENTO
          ,PRESTADOR.DS_CIDADE
          ,PRESTADOR.NM_UF
          ,PRESTADOR.NR_CEP
          ,PRESTADOR.CD_MULTI_EMPRESA
          ,PRESTADOR.TP_SITUACAO
      FROM DBAPS.PRESTADOR
    WHERE (LPad(NR_CPF_CGC, 14, '0') = NVL(regexp_replace(PCD_PRESTADOR, '[^[:digit:]]+'), lpad(regexp_replace(PNR_CNPJCPF, '[^[:digit:]]+'), 14, '0'))
        OR PRESTADOR.CD_INTERNO = to_char(regexp_replace(PCD_PRESTADOR, '[^[:digit:]]+'))
        OR PRESTADOR.CD_PRESTADOR = regexp_replace(PCD_PRESTADOR, '[^[:digit:]]+')
        OR PRESTADOR.cd_registro_ans_intermed = regexp_replace(NR_REGISTRO_ANS, '[^[:digit:]]+')
        )
        --AND TP_SITUACAO = 'A'
        AND CD_MULTI_EMPRESA = nvl(P_CD_MULTI_EMPRESA, DBAMV.PKG_MV2000.LE_EMPRESA);



  /**
   * Verifica se a senha enviada pelo prestador no login do WebService deve ser
   * validada junto ao Hash MD5
   */
  CURSOR cChaveSenhaMD5(P_CD_MULTI_EMPRESA IN NUMBER) IS
    SELECT VALOR FROM DBAPS.MVS_CONFIGURACAO
      WHERE CHAVE = 'WEBSERVICE_SENHA_MD5'
        AND CD_MULTI_EMPRESA = Nvl(P_CD_MULTI_EMPRESA, DBAMV.PKG_MV2000.LE_EMPRESA);

  /**
   * Verifica se o login e senha do prestador ser?o verificados no cabecalho de cada mensagem
   * TISS a partir da vers?o 3.01.00
   */
  CURSOR cChaveValidaLoginSenha(P_CD_MULTI_EMPRESA IN NUMBER) IS
    SELECT VALOR FROM DBAPS.MVS_CONFIGURACAO
      WHERE CHAVE = 'WEBSERVICE_VALIDA_LOGIN_SENHA'
        AND CD_MULTI_EMPRESA = Nvl(P_CD_MULTI_EMPRESA, DBAMV.PKG_MV2000.LE_EMPRESA);

  /**
   * Dados do desligamento do prestador
   */
  CURSOR cDesligPrest(P_CD_PRESTADOR IN NUMBER) IS
    SELECT Max(DT_DESLIGAMENTO) DT_DESLIGAMENTO FROM DBAPS.DESLIGA_PRESTADOR
    WHERE CD_PRESTADOR = P_CD_PRESTADOR
    AND DT_REATIVACAO IS NULL;

-- Variaveis Relativas aos Parametros informados na mensagem TISS
vNrRegistroAns                NUMBER;
vNrCnpjOperadora              VARCHAR2(100);
vCdCodigoPrestador            VARCHAR2(100);
vNrCnpjCpfPrestador           VARCHAR2(100);

-- Variaveis
rTissMensagem                 cTissMensagem%ROWTYPE;
rPlanoDeSaude                 cPlanoDeSaude%ROWTYPE;
rDesligPrest                  cDesligPrest%ROWTYPE;
vCount                        NUMBER;
vSenhaValida                  VARCHAR2(1);
vCdPrestador                  NUMBER;
vChaveSenhaMD5                VARCHAR2(2);
cValidaLoginSenha             VARCHAR2(1);
vTpSituacao                   VARCHAR2(5);

BEGIN

 /**************************************************************************************
  *   1? PASSO - FILTRAGEM DE PARAMETROS RECEBIDOS
  **************************************************************************************/

  BEGIN
    OPEN  cTissMensagem;
    FETCH cTissMensagem INTO rTissMensagem;
    CLOSE cTissMensagem;

    vNrRegistroAns                :=  regexp_replace(rTissMensagem.NR_REGISTRO_ANS_DESTINO,'[^[:digit:]]+');
    vNrCnpjOperadora              :=  regexp_replace(rTissMensagem.NR_CNPJ_PAGADOR_DESTINO,'[^[:digit:]]+');
    vCdCodigoPrestador            :=  regexp_replace(rTissMensagem.CD_PRESTADOR_OPERADORA,'[^[:digit:]]+');
    vNrCnpjCpfPrestador           :=  regexp_replace(rTissMensagem.NR_CNPJCPF_PRESTADOR,'[^[:digit:]]+');

  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(SQLERRM, 'ORA', 1, 1) <> 0 THEN
        P_CD_GLOSA := '5013';
        P_DS_GLOSA := 'ERRO AO PROCESSAR DADOS DA MENSAGEM TISS. ERRO; '|| SQLERRM ||' LINHA DO ERRO: '|| DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
      END IF;
  END;

  /* Validando Vers?o */
  IF rTissMensagem.CD_VERSAO NOT IN ('3.05.01', '3.05.00','3.04.01','3.04.00', '3.03.03','3.03.02','3.03.01','3.03.00','3.02.02','3.02.01', '3.02.00', '3.01.00' ,'2.02.03', '2.02.02', '2.02.01', '2.01.03') THEN
        P_CD_GLOSA := '5013';
        P_DS_GLOSA := 'VERSAO TISS INVALIDA. APENAS AS VERSOES 3.04.01, 3.04.00, 3.03.03, 3.03.02, 3.03.01, 3.03.00, 3.02.02, 3.02.01, 3.02.00, 3.01.00 , 2.02.03, 2.02.02, 2.02.01 e 02.01.03 S?O ACEITAS';
  END IF;

  /* Validando Operadora */
  IF P_CD_GLOSA IS NULL THEN

    OPEN cPlanoDeSaude(vNrRegistroAns, vNrCnpjOperadora);
    FETCH cPlanoDeSaude INTO rPlanoDeSaude;

    IF (cPlanoDeSaude%NOTFOUND) THEN

      IF vNrCnpjOperadora IS NOT NULL THEN
        P_CD_GLOSA := '5004';
        P_DS_GLOSA := 'DESTINATARIO INVALIDO - CNPJ DA OPERADORA N?O IDENTIFICADO';
      ELSE
        P_CD_GLOSA := '5004';
        P_DS_GLOSA := 'DESTINATARIO INVALIDO - NUMERO DE REGISTRO DA OPERADORA NA ANS INVALIDO';
      END IF;

    ELSE
        P_NR_REGISTRO_ANS   :=  rPlanoDeSaude.NR_ANS;
        P_CD_MULTI_EMPRESA  :=  rPlanoDeSaude.CD_MULTI_EMPRESA;
        P_DS_OPERADORA      :=  rPlanoDeSaude.DS_MULTI_EMPRESA;
        P_NR_CNPJ_OPERADORA :=  lpad(to_char(rPlanoDeSaude.CD_CGC), 14, '0');
    END IF;

    CLOSE cPlanoDeSaude;

  END IF;

  /* Configurando a multi_empresa da operadora */
  IF P_CD_GLOSA IS NULL THEN

    IF rPlanoDeSaude.CD_MULTI_EMPRESA IS NOT NULL THEN
      DBAMV.PKG_MV2000.ATRIBUI_EMPRESA(rPlanoDeSaude.CD_MULTI_EMPRESA);
    ELSE
      P_CD_GLOSA := '5013';
      P_DS_GLOSA := 'CODIGO MULTI_EMPRESA NAO CONFIGURADO. ENTRE EM CONTATO COM A OPERADORA';
    END IF;

  END IF;

  /* Validando dados do prestador */
    BEGIN
      /* Validar prestador em duplicade na mesma multi_empresa */
      vCount := 0;

      FOR rPrestador IN cPrestador(vCdCodigoPrestador, vNrCnpjCpfPrestador, P_CD_MULTI_EMPRESA, rTissMensagem.NR_REGISTRO_ANS_ORIGEM) LOOP
        vCount := vCount +1;
        P_CD_PRESTADOR_OPERADORA := rPrestador.cd_prestador;
        vTpSituacao := rPrestador.TP_SITUACAO;
      END LOOP;

    IF P_CD_GLOSA IS NULL AND rTissMensagem.CD_VERSAO >= '3.01.00' THEN

      IF vCount = 0 THEN
          P_CD_GLOSA := '1203';
          P_DS_GLOSA := 'CODIGO PRESTADOR INVALIDO OU INATIVO [NO ORIGEM]';
      END IF;

      IF vCount = 1 and vTpSituacao <> 'A' THEN

          OPEN cDesligPrest(P_CD_PRESTADOR_OPERADORA);
          FETCH cDesligPrest INTO rDesligPrest;
          CLOSE cDesligPrest;

          --permitir o envio de XML 180 dias apos o desligamento do prestador
          IF Trunc(rDesligPrest.DT_DESLIGAMENTO+180) < Trunc(SYSDATE) THEN
            P_CD_GLOSA := '1203';
            P_DS_GLOSA := 'PRESTADOR INATIVO. ENTRE EM CONTATO COM A OPERADORA [NO ORIGEM]';
          END IF;
      END IF;

      IF vCount > 1 THEN
          P_CD_GLOSA := '1203';
          P_DS_GLOSA := 'CODIGO PRESTADOR [NO ORIGEM] COM MAIS DE UM REGISTRO. ENTRE EM CONTATO COM A OPERADORA';
      END IF;

    END IF;

    EXCEPTION
      WHEN OTHERS THEN

        P_CD_GLOSA := '1203';
        P_DS_GLOSA := 'CODIGO DO PRESTADOR NAO CADASTRADADO NA OPERADORA [E] [NO ORIGEM] '||SQLERRM;
    END;

    OPEN cChaveValidaLoginSenha(rPlanoDeSaude.CD_MULTI_EMPRESA);
    FETCH cChaveValidaLoginSenha INTO cValidaLoginSenha;
    CLOSE cChaveValidaLoginSenha;

   /* Validando login/senha do prestador */
  IF P_CD_GLOSA IS NULL AND rTissMensagem.CD_VERSAO >= '3.01.00'
    AND rTissMensagem.NR_WS_IP_REMETENTE <> 'MV'
    AND Nvl(cValidaLoginSenha, 'N') = 'S' THEN

      OPEN cChaveSenhaMD5(rPlanoDeSaude.CD_MULTI_EMPRESA);
      FETCH cChaveSenhaMD5 INTO vChaveSenhaMD5;
      CLOSE cChaveSenhaMD5;

     vSenhaValida := dbaps.fnc_mvs_valida_prestador_senha(rTissMensagem.DS_LOGIN_PRESTADOR, rTissMensagem.DS_SENHA_PRESTADOR,
                      Nvl(vChaveSenhaMD5, 'N'), rPlanoDeSaude.CD_MULTI_EMPRESA);

    IF (vSenhaValida = 'N') THEN
        P_CD_GLOSA := '5005';
        P_DS_GLOSA := 'REMETENTE N?O IDENTIFICADO - LOGIN OU SENHA do PRESTADOR INVALIDOS';
    END IF;

  END IF;

END;
/

GRANT EXECUTE ON dbaps.prc_tiss_valida_cabecalho TO dbamv
/
GRANT EXECUTE ON dbaps.prc_tiss_valida_cabecalho TO dbasgu
/
GRANT EXECUTE ON dbaps.prc_tiss_valida_cabecalho TO mv2000
/
GRANT EXECUTE ON dbaps.prc_tiss_valida_cabecalho TO mvintegra
/
