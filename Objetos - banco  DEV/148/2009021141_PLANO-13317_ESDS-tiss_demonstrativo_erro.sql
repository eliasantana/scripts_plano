PROMPT CREATE OR REPLACE PROCEDURE dbaps.prc_tiss_demonstrativos
CREATE OR REPLACE PROCEDURE dbaps.prc_tiss_demonstrativos(P_ID_TISS_MENSAGEM     IN NUMBER
																									 ,P_ID_TISS_MENSAGEM_OUT OUT NUMBER) IS
	/**************************************************************
    <objeto>
     <nome>prc_tiss_demonstrativos</nome>
     <usuario>Elias Santana da Silva</usuario>
     <alteracao>02/09/2020 16:04h</alteracao>
     <ultimaAlteracao>Alteração no cursor cProtocoloCmGuiaProcedimento, para enviar separado o numero da guia da operadora e do prestador.
     alterações nos cursores para os clientes que utilizam folha de pagamento</ultimaAlteracao>
     <descricao>
     function chamada pelo webservice Demonstrativo retorno
                   que retorna os dados de uma análise de conta médica ou
                   dados de um extrato de pagamento. Atualmente já possui integração com
                   financeiro ou não (dependendo da operadora)
       Alteração : Foi atualizado os select para que atenda a nova tela de repasse prestado
     </descricao>
     <parametro>P_ID_TISS_MENSAGEM</parametro>
     <tags>guia, protocolo, xml, tiss</tags>
     <versao>1.7</versao>
     <soul>PLANO.01.147</soul>
    </objeto>
  ***************************************************************/
	/****************************************************************************
  * Cursor que verifica se O webservice de demonstrativo de retorno está
  * ativo (via chave  WEBSERVICE_DEMONST_RETORNO)
  ****************************************************************************/
	CURSOR cWebserviceAtivo(P_CD_MULTI_EMPRESA IN NUMBER) IS
		SELECT VALOR
			FROM DBAPS.MVS_CONFIGURACAO
		 WHERE CHAVE = 'WEBSERVICE_DEMONST_RETORNO'
			 AND CD_MULTI_EMPRESA =
					 NVL(P_CD_MULTI_EMPRESA, DBAMV.PKG_MV2000.LE_EMPRESA);
	--
	--
	/*****************************************************************************
  * Cursor que busca os dados Mensagem ***************************************
  * Atenção: a coluna tp_demonstrativo é preenchida pelo mvsaudews para informar o
  * tipo de demonstrativo retorno...
  ******************************************************************************/
	CURSOR cTissMensagem IS
		SELECT TM.ID
					,TDR.CD_TISS_DEMNSTRV_RETORNO ID_DEM_RETORNO
					,TM.NR_REGISTRO_ANS_DESTINO
					,TM.NR_CNPJ_PRESTADOR_OPERADORA
					,TM.NR_CPF_PRESTADOR_OPERADORA
					,TM.CD_PRESTADOR_OPERADORA
					,TM.CD_VERSAO
					,TM.NR_CNPJ_PAGADOR_DESTINO
					,TM.DS_LOGIN_PRESTADOR
					,TM.DS_SENHA_PRESTADOR
					,NVL(TO_DATE(DT_TRANSACAO || ' ' || SubStr(HR_TRANSACAO, 1, 8), 'YYYY-MM-DD HH24:MI:SS'), SYSDATE) DT_TRANSACAO
					,TDR.TP_DEMONSTRATIVO
			FROM DBAPS.TISS_MENSAGEM         TM
					,DBAPS.TISS_DEMNSTRV_RETORNO TDR
		 WHERE TM.ID = TDR.CD_PAI
			 AND TM.ID = P_ID_TISS_MENSAGEM;
	--
	--
	/*****************************************************************************
  * Cursor que busca a solicitacao de demonstrativo
  * (1-pagamento ou 2 - análise de contas)
  ****************************************************************************/
	CURSOR cSolicitacao(P_ID_DEM_RETORNO IN NUMBER) IS
		SELECT CD_PRESTADOR_CONTRATADO
					,NR_CNPJ_CONTRATADO
					,NR_CPF_CONTRATADO
					,NM_CONTRATADO
					,DT_SOLICITACAO
					,TP_DEMONSTRATIVO
					,DT_PAGAMENTO
					,DT_COMPETENCIA
			FROM DBAPS.TISS_DEMNSTRV_RETORNO
		 WHERE CD_TISS_DEMNSTRV_RETORNO = P_ID_DEM_RETORNO;
	--
	--
	/* Cursor que obtém os dados do prestador **********************************/
	CURSOR cDadosPrestador(PCD_PRESTADOR      IN NUMBER
												,PNR_CNPJCPF        IN VARCHAR
												,P_CD_MULTI_EMPRESA IN NUMBER) IS
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
					,PRESTADOR.CD_CIDADE
					,PRESTADOR.NR_CONTA
					,PRESTADOR.DS_NR_AGENCIA AS NR_AGENCIA
					,PRESTADOR.CD_BANCO
					,Nvl((SELECT E.CD_CNES
								 FROM DBAPS.PRESTADOR_ENDERECO E
								WHERE E.CD_PRESTADOR = PRESTADOR.CD_PRESTADOR
									AND E.SN_PRINCIPAL = 'S'
									AND E.CD_CNES IS NOT NULL
									AND ROWNUM = 1), '9999999') CD_CNEs
          ,PRESTADOR.TP_CREDENCIAMENTO
			FROM DBAPS.PRESTADOR
		 WHERE (LPad(NR_CPF_CGC, 14, '0') =
					 NVL(lpad(PNR_CNPJCPF, 14, '0'), lpad(-1, 14, '0')) OR
					 PRESTADOR.CD_INTERNO = to_char(PCD_PRESTADOR) OR
					 PRESTADOR.CD_PRESTADOR = PCD_PRESTADOR)
			 AND TP_SITUACAO = 'A'
			 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA;
	--
	--
	/* Cursor que obtém CD_TISS e DS_MOTIVO do motivo da glosa ******************/
	CURSOR cMotivoGlosa(P_CD_MOTIVO_GLOSA IN NUMBER) IS
		SELECT DS_MOTIVO
					,Nvl(CD_TISS, 'TODO_CD_TISS') CD_TISS --TODO
			FROM dbaps.motivo_glosa
		 WHERE CD_MOTIVO = P_CD_MOTIVO_GLOSA;
	--
	--
	/**
  * Cursor que busca o código da tabela
  */
	CURSOR cTabela(P_CD_PROCEDIMENTO IN VARCHAR2) IS
		SELECT CD_TABELA
			FROM (SELECT '18' CD_TABELA
							FROM DBAPS.TISS_INSTALACAO_TABELA_18
						 WHERE CD_PROCEDIMENTO = P_CD_PROCEDIMENTO
						UNION
						SELECT '19' CD_TABELA
							FROM DBAPS.TISS_INSTALACAO_TABELA_19
						 WHERE CD_PROCEDIMENTO = P_CD_PROCEDIMENTO
						UNION
						SELECT '20' CD_TABELA
							FROM DBAPS.TISS_INSTALACAO_TABELA_20
						 WHERE CD_PROCEDIMENTO = P_CD_PROCEDIMENTO
						UNION
						SELECT '22' CD_TABELA
							FROM DBAPS.TISS_INSTALACAO_TABELA_22
						 WHERE CD_PROCEDIMENTO = P_CD_PROCEDIMENTO);
	--
	--
	/**
  * BUSCA OS DADOS DO PROTOCOLO APRESENTADO DE CONTAS MÉDICAS
  */
	CURSOR cProtocoloCtamed(P_NR_PROTOCOLO IN VARCHAR2) IS
		SELECT PRO.CD_PROTOCOLO_CTAMED
					,PRO.NR_LOTE_PRESTADOR
					,PRO.DT_ENVIO_LOTE
					,PRO.CD_STATUS_PROTOCOLO
					,PRO.CD_PRESTADOR
					,PRO.CD_GLOSA_PROTOCOLO
					,PRO.DT_ENVIO_LOTE DT_ENVIO
					,P.NM_PRESTADOR
					,L.CD_LOTE
					,PRO.ID_TISSLOTGUIA
			FROM DBAPS.PROTOCOLO_CTAMED PRO
					,DBAPS.PRESTADOR        P
					,DBAPS.LOTE             L
		 WHERE PRO.CD_PRESTADOR = P.CD_PRESTADOR
			 AND PRO.CD_PROTOCOLO_CTAMED = L.CD_PROTOCOLO_CTAMED(+)
			 AND PRO.CD_PROTOCOLO_CTAMED = P_NR_PROTOCOLO;
	--
	--
	-- Variáveis dos Cursores
	rTissMensagem    cTissMensagem%ROWTYPE;
	rSolicitacao     cSolicitacao%ROWTYPE;
	rWebserviceAtivo cWebserviceAtivo%ROWTYPE;
	rDadosPrestador  cDadosPrestador%ROWTYPE;
	rMotivoGlosa     cMotivoGlosa%ROWTYPE;
	-- Variaveis Regra de Negócio
	nIdTissMensagem    DBAPS.TISS_MENSAGEM.ID%TYPE;
	nIdTissDemAna      DBAPS.TISS_DEM_ANA.ID%TYPE;
	nIdTissDemErro     DBAPS.TISS_MENSAGEM.ID%TYPE;
	nIdTissMensagemLog DBAPS.TISS_MENSAGEM_LOG.CD_TISS_MENSAGEM_LOG%TYPE;
	nCdPrestador       NUMBER(38);
  vTpCredenciado     VARCHAR2(2);
	nDsPrestador       VARCHAR2(1000);
	nCdCnes            NUMBER(10);
	vExcecao           VARCHAR2(2000);
	vExcecaoLinha      VARCHAR2(2000);
	vTpTransacao       VARCHAR2(100);
	vNmXML             VARCHAR2(100);
	vCdTissTabela      VARCHAR2(5);
	bPrestadorValido   VARCHAR2(10);
	bRegistroAnsValido VARCHAR2(10);
	-- Armazena variáveis de retorno do cabeçalho
	nCdPrestadorNaOperadora NUMBER;
	nNrCnpjPrestador        VARCHAR2(20);
	nNrCpfPrestador         VARCHAR2(20);
	nCdMultiEmpresaOrigem   NUMBER;
	nNrRegistroAnsOrigem    NUMBER;
	vDsOperadora            VARCHAR2(4000);
	nCnpjOperadora          VARCHAR2(14);
	vCdGlosa                VARCHAR2(10);
	vDsGlosa                VARCHAR2(500);
	-- variaveis auxiliares
	vVersaoTiss VARCHAR2(10);
	vCount      NUMBER;
	/*****************************************************************************
  ********************** DECLARAÇÃO DE FUNÇÕES ********************************
  ****************************************************************************/
	/*****************************************************************************
  * Grava uma resposta para o demonstrativo de ANÁLISE
  * Pode solicitar até o status de 30 protocolos
  ****************************************************************************/
	FUNCTION gravarRespostaDemAnalise(P_ID_DEM_RETORNO         IN NUMBER
																	 ,P_ID_TISS_MENSAGEM       IN NUMBER
																	 ,P_NR_REGISTRO_ANS        IN VARCHAR2
																	 ,P_CNPJ_OPERADORA         IN VARCHAR2
																	 ,P_DS_OPERADORA           IN VARCHAR2
																	 ,P_CD_VERSAO              IN VARCHAR2
																	 ,P_CD_PRESTADOR_OPERADORA IN VARCHAR2
																	 ,P_NR_CNPJ_PRESTADOR      IN VARCHAR2
																	 ,P_NR_CPF_PRESTADOR       IN VARCHAR2
																	 ,P_CD_GLOSA_CABECALHO     IN VARCHAR2
																	 ,P_DS_GLOSA_CABECALHO     IN VARCHAR2
																	 ,P_CD_MULTI_EMPRESA       IN NUMBER)
		RETURN NUMBER IS
		/* Cursor que busca os protocolos da solicitacao de demonstrativo de análise */
		CURSOR cSolicitacaoProtocolo(P_CD_PAI IN NUMBER) IS
			SELECT NR_PROTOCOLO
				FROM DBAPS.TISS_DEMNSTRV_RETORNO_PROTO
			 WHERE CD_PAI = P_CD_PAI;
		/* Cursor que obtém os dados do lote de guias em contas médicas ***********/
		CURSOR cProtocolo(P_CD_PROTOCOLO           IN VARCHAR
										 ,P_CD_PRESTADOR_PRINCIPAL IN NUMBER) IS
			SELECT FAT.CD_FATURA CD_FATURA
						,PRO.CD_PROTOCOLO_CTAMED -- numeroProtocolo
						,PRO.NR_LOTE_PRESTADOR NR_LOTE_PRESTADOR -- numeroLotePrestador
						,PRO.DT_ENVIO_LOTE DT_ENVIO -- dataProtocolo
						,SUM(CTA.VL_TOTAL_COBRADO) VL_TOTAL_COBRADO -- Valor informado do protocolo
						 -- apenas pagamentos feitos para o prestador que solicitou a mensagem no tiss serão exibidos
						,(SELECT SUM(VCM.VL_TOTAL_PAGO) VL_TOTAL_PAGO
								FROM DBAPS.V_CTAS_MEDICAS VCM
										,DBAPS.LOTE           LOT
							 WHERE VCM.CD_LOTE = LOT.CD_LOTE
								 AND LOT.cd_protocolo_ctamed = TO_NUMBER(P_CD_PROTOCOLO)
								 AND DBAPS.fnc_mvs_retorna_prestador_rep(VCM.cd_prestador_principal, Nvl(VCM.
																															cd_prestador, VCM.cd_prestador_principal)) =
										 P_CD_PRESTADOR_PRINCIPAL) VL_TOTAL_PAGO
						,SUM(CTA.VL_TOTAL_GLOSADO) VL_TOTAL_GLOSADO -- Valor da glosa do protocolo
						,PRO.CD_STATUS_PROTOCOLO -- Status do protocolo
						,PRO.CD_GLOSA_PROTOCOLO
						,GT.DS_GLOSA
				FROM DBAPS.V_CTAS_MEDICAS   CTA
						,DBAPS.LOTE             LOT
						,DBAPS.FATURA           FAT
						,DBAPS.PROTOCOLO_CTAMED PRO
						,DBAPS.GLOSA_TISS       GT
			 WHERE CTA.CD_LOTE = LOT.CD_LOTE
				 AND LOT.CD_FATURA = FAT.CD_FATURA(+)
				 AND CTA.CD_PRESTADOR_PRINCIPAL = P_CD_PRESTADOR_PRINCIPAL
				 AND PRO.CD_PROTOCOLO_CTAMED = LOT.CD_PROTOCOLO_CTAMED(+)
				 AND PRO.CD_GLOSA_PROTOCOLO = GT.CD_GLOSA(+)
				 AND PRO.CD_PROTOCOLO_CTAMED = TO_NUMBER(P_CD_PROTOCOLO)
				 AND CTA.TP_SITUACAO NOT IN ('NA', 'GA') -- apenas itens auditados
			 GROUP BY CTA.CD_FATURA
							 ,FAT.DT_VENCIMENTO
							 ,LOT.CD_PROTOCOLO_CTAMED
							 ,PRO.NR_LOTE_PRESTADOR
							 ,PRO.DT_ENVIO_LOTE
							 ,PRO.CD_STATUS_PROTOCOLO
							 ,FAT.CD_FATURA
							 ,PRO.CD_PROTOCOLO_CTAMED
							 ,PRO.CD_GLOSA_PROTOCOLO
							 ,GT.DS_GLOSA;
		/**
    * CURSOR QUE OBTÉM OS DADOS DAS GUIAS DE UM LOTE EM CONTAS MÉDICAS
    * 07/07/2014 - na presente data não existia no módulo de contas médicas um status por guia
    * dessa forma foi considerado que se a guia possuir um item a ser pago seu status é ANALISADO e LiBERADO PARA PAGAMENTO
    * caso contrário informa-se o status como EM ANALISE.
    * - Os demais status não foram passíveis de implementação.
    */
		CURSOR cProtocoloCmGuia(P_CD_PROTOCOLO           IN VARCHAR
													 ,P_CD_PRESTADOR_PRINCIPAL IN NUMBER) IS
			SELECT NR_GUIA_PRESTADOR
						,NR_GUIA_OPERADORA
						,NR_SENHA
						,NM_BENEFICIARIO
						,NR_CARTEIRA
						,DT_INICIO_FAT
						,DT_FIM_FAT
						,NR_CNS
						,DT_REALIZACAO
						,CD_IDENT_BENEFICIARIO
						,CD_PRESTADOR
						,NM_CONTRATADO
						,SN_ATENDIMENTO_RECEM_NATO
						,DECODE(SN_POSSUI_LIBERADO_PAGAMENTO, 'S', 5 -- 5: ANALISADO E LIBERADO PARA PAGAMENTO
									 , 2 -- 2: EM ANÁLISE
										) CD_STATUS_GUIA
						,SUM(VL_PROCESSADO) VL_PROCESSADO
						,SUM(VL_LIBERADO) VL_LIBERADO
						,SUM(VL_GLOSADO) VL_GLOSADO
						,SUM(VL_INFORMADO) VL_INFORMADO
				FROM (SELECT CTA.CD_GUIA_EXTERNA NR_GUIA_PRESTADOR
										,CTA.NR_GUIA NR_GUIA_OPERADORA
										,CTA.NR_GUIA NR_SENHA --NO PRESENTE MOMENTO GUIA NA OPERADORA E SENHA SAO A MESMA COISA
										,Nvl(USU.NM_SEGURADO, cta.NM_BENEFICIARIO) NM_BENEFICIARIO
										,
										 --Nvl(USU.CD_MATRICULA, cta.NR_CARTEIRA_BENEFICIARIO) NR_CARTEIRA,
										 Nvl(To_Char(USU.CD_MATRICULA), cta.NR_CARTEIRA_BENEFICIARIO) NR_CARTEIRA
										,CTA.DT_ENTRADA DT_INICIO_FAT
										,CTA.DT_SAIDA DT_FIM_FAT
										,USU.NR_CNS
										,CTA.DT_REALIZADO DT_REALIZACAO
										,NULL CD_IDENT_BENEFICIARIO
										,CTA.CD_PRESTADOR CD_PRESTADOR
										,Nvl(CTA.NM_PRESTADOR, PRE.NM_PRESTADOR) NM_CONTRATADO
										,GUI.SN_ATENDIMENTO_RECEM_NATO
										,NVL((SELECT 'S'
													 FROM DBAPS.V_CTAS_MEDICAS V
													WHERE V.CD_CONTA_MEDICA = CTA.CD_CONTA_MEDICA
														AND V.CD_LOTE = CTA.CD_LOTE
														AND V.TP_ORIGEM = 2
														AND V.CD_MOTIVO IS NULL
														AND V.VL_TOTAL_PAGO > 0
														AND ROWNUM = 1), 'N') SN_POSSUI_LIBERADO_PAGAMENTO
										,SUM(CTA.QT_COBRADO * CTA.VL_UNIT_COBRADO) VL_PROCESSADO
										 -- apenas pagamentos feitos para o prestador que solicitou a mensagem no tiss serão exibidos
										,(SELECT SUM(VCM.VL_TOTAL_PAGO) VL_TOTAL_PAGO
												FROM DBAPS.V_CTAS_MEDICAS VCM
														,DBAPS.LOTE           LOT
											 WHERE VCM.CD_LOTE = LOT.CD_LOTE
												 AND LOT.CD_PROTOCOLO_CTAMED =
														 TO_NUMBER(P_CD_PROTOCOLO)
												 AND DBAPS.FNC_MVS_RETORNA_PRESTADOR_REP(VCM.CD_PRESTADOR_PRINCIPAL, Nvl(VCM.CD_PRESTADOR, VCM.CD_PRESTADOR_PRINCIPAL)) =
														 P_CD_PRESTADOR_PRINCIPAL
												 AND (VCM.CD_GUIA_EXTERNA = CTA.CD_GUIA_EXTERNA OR
														 VCM.NR_GUIA = CTA.NR_GUIA)) VL_LIBERADO
										,SUM(CTA.VL_TOTAL_GLOSADO) VL_GLOSADO
										 --,(SELECT VL_PROCEDIMENTO FROM DBAPS.V_TISS_LOTE_GUIA WHERE id = CTA.ID_TISS_ITEM) VL_INFORMADO
										,CTA.VL_TOTAL_COBRADO VL_INFORMADO
								FROM DBAPS.V_CTAS_MEDICAS   CTA
										,DBAPS.LOTE             LOT
										,DBAPS.GUIA             GUI
										,DBAPS.USUARIO          USU
										,DBAPS.PROTOCOLO_CTAMED PRO
										,DBAPS.PRESTADOR        PRE
							 WHERE LOT.CD_LOTE = CTA.CD_LOTE
								 AND LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED
								 AND LOT.CD_PROTOCOLO_CTAMED = TO_NUMBER(P_CD_PROTOCOLO)
								 AND CTA.CD_PRESTADOR = PRE.CD_PRESTADOR(+)
								 AND CTA.NR_GUIA = GUI.NR_GUIA(+)
								 AND GUI.CD_MATRICULA = USU.CD_MATRICULA(+)
								 AND CTA.TP_SITUACAO NOT IN ('NA', 'GA') -- apenas itens auditados
							 GROUP BY CTA.CD_GUIA_EXTERNA
											 ,CTA.NR_GUIA
											 ,USU.NM_SEGURADO
											 ,USU.CD_MATRICULA
											 ,CTA.NM_BENEFICIARIO
											 ,CTA.VL_TOTAL_COBRADO
											 ,CTA.NR_CARTEIRA_BENEFICIARIO
											 ,CTA.DT_ENTRADA
											 ,CTA.DT_SAIDA
											 ,USU.NR_CNS
											 ,CTA.DT_REALIZADO
											 ,CTA.DT_REALIZADO
											 ,CTA.CD_PRESTADOR
											 ,CTA.NM_PRESTADOR
											 ,PRE.NM_PRESTADOR
											 ,GUI.SN_ATENDIMENTO_RECEM_NATO
											 ,CTA.CD_CONTA_MEDICA
											 ,CTA.CD_LOTE
											 ,CTA.ID_TISS_ITEM)
			 WHERE CD_PRESTADOR = P_CD_PRESTADOR_PRINCIPAL
			 GROUP BY NR_GUIA_PRESTADOR
							 ,NR_GUIA_OPERADORA
							 ,NR_SENHA
							 ,NM_BENEFICIARIO
							 ,NR_CARTEIRA
							 ,DT_INICIO_FAT
							 ,DT_FIM_FAT
							 ,NR_CNS
							 ,DT_REALIZACAO
							 ,CD_IDENT_BENEFICIARIO
							 ,CD_PRESTADOR
							 ,NM_CONTRATADO
							 ,SN_ATENDIMENTO_RECEM_NATO
							 ,SN_POSSUI_LIBERADO_PAGAMENTO;
		/**
    * CURSOR QUE OBÉM OS DADOS DOS PROCEDIMENTOS DE UMA GUIA
    * No padrão tiss 3.02... a ANS mesclou a equipe médica (grauParticipacao) junto com os procedimentos
    * no nó (detalhesGuia). Dessa forma para apresentar a equipe repete-se o código do procedimento
    * várias vezes (semelhante a modelagem de contas médicas da MV)
    *
    * Detalhe: apenas contas auditadas são exibidas no demonstrativo
    */
		CURSOR cProtocoloCmGuiaProcedimento(P_CD_PROTOCOLO           IN VARCHAR
																			 ,P_NR_GUIA_OPE            IN NUMBER
																			 ,P_NR_GUIA_PREST          IN VARCHAR
																			 ,P_CD_PRESTADOR_PRINCIPAL IN NUMBER) IS
			SELECT CTA.DT_REALIZADO DT_REALIZACAO
						,CTA.CD_PROCEDIMENTO
						,CTA.DS_PROCEDIMENTO
						,CTA.CD_MOTIVO CD_TIPO_GLOSA
						,CTA.CD_ATIVIDADE_MEDICA CD_GRAU_PARTICIPACAO
						,SUM(CTA.VL_TOTAL_COBRADO) VL_INFORMADO
						,SUM(CTA.VL_TOTAL_PAGO) VL_LIBERADO
						,SUM(CTA.VL_TOTAL_GLOSADO) VL_GLOSA
						,SUM(CTA.QT_PAGO) QT_EXECUTADA
						,CTA.DT_REALIZADO DT_EXECUCAO
						,CTA.VL_UNIT_PAGO VL_UNIT_PAGO
						,CTA.VL_TOTAL_COBRADO VL_TOTAL
				FROM DBAPS.V_CTAS_MEDICAS   CTA
						,DBAPS.LOTE             LOT
						,DBAPS.GUIA             GUI
						,DBAPS.USUARIO          USU
						,DBAPS.PROTOCOLO_CTAMED PRO
			 WHERE LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED
				 AND LOT.CD_LOTE = CTA.CD_LOTE
				 AND CTA.NR_GUIA = GUI.NR_GUIA(+)
				 AND CTA.CD_MATRICULA = USU.CD_MATRICULA(+)
				 AND LOT.CD_PROTOCOLO_CTAMED = P_CD_PROTOCOLO
				 AND (CTA.NR_GUIA = P_NR_GUIA_OPE OR
						 CTA.CD_GUIA_EXTERNA = P_NR_GUIA_PREST)
						-- apenas pagamentos feitos para o prestador que solicitou a mensagem no tiss serão exibidos
				 AND DBAPS.fnc_mvs_retorna_prestador_rep(CTA.cd_prestador_principal, Nvl(CTA.
																											cd_prestador, CTA.cd_prestador_principal)) =
						 P_CD_PRESTADOR_PRINCIPAL
				 AND CTA.TP_SITUACAO NOT IN ('NA', 'GA') --apenas itens auditados
			 GROUP BY CTA.CD_LANCAMENTO
							 ,CTA.DT_REALIZADO
							 ,CTA.CD_TABELA
							 ,CTA.CD_PROCEDIMENTO
							 ,CTA.DS_PROCEDIMENTO
							 ,CTA.CD_MOTIVO
							 ,CTA.CD_ATIVIDADE_MEDICA
							 ,CTA.VL_TOTAL_COBRADO
							 ,CTA.VL_UNIT_PAGO;
		/* Início da declaração das variáveis ***************************************/
		nCount                     NUMBER;
		nIdTissDemAnaFatLot        DBAPS.TISS_DEM_ANA_FAT_LOT.ID%TYPE;
		nIdTissDemAnaFatLotGui     DBAPS.TISS_DEM_ANA_FAT_LOT_GUI.ID%TYPE;
		nIdTissDemAnaFatLotGuiPr   DBAPS.TISS_DEM_ANA_FAT_LOT_GUI_PR.ID%TYPE;
		nIdTissDemAnaFatLotGuiPrGl DBAPS.TISS_DEM_ANA_FAT_LOT_GUI_PR_GL.ID%TYPE;
		nSumVlInformadoGeral       NUMBER(10, 2);
		nSumVlProcessadoGeral      NUMBER(10, 2);
		nSumVlLiberadoGeral        NUMBER(10, 2);
		nSumVlGlosaGeral           NUMBER(10, 2);
		vProtNaoLocalizadosPrest   VARCHAR2(2000);
		vProtNaoLocalizadosContMed VARCHAR2(2000);
		vNrProtocolo               VARCHAR2(50);
		vHrEntrada                 VARCHAR2(10);
		vHrSaida                   VARCHAR2(10);
		/* Variáveis dos Cursores ***************************************************/
		rSolicitacaoProtocolo        cSolicitacaoProtocolo%ROWTYPE;
		rProtocoloCMGuia             cProtocoloCMGuia%ROWTYPE;
		rProtocoloCmGuiaProcedimento cProtocoloCmGuiaProcedimento%ROWTYPE;
		rProtocoloCtamed             cProtocoloCtamed%ROWTYPE;
		/* Variáveis de retorno do cursor de cProtocolo *****************************/
		nCdFatura              NUMBER(32);
		nCdProcoloCtaMed       NUMBER(32);
		nDemonstrativo         NUMBER(32);
		nVlInformadoProtocolo  NUMBER;
		nVlliberadoProtocolo   NUMBER;
		nVlGlosaProtocolo      NUMBER;
		nVlProcessadoProtocolo NUMBER;
		vCdStatusProtocolo     VARCHAR2(2);
		nNrLotePrestador       VARCHAR2(100);
		dDtEnvioLote           DATE;
		dDtPagamento           DATE;
		nTissSitDemRetorno     NUMBER(32);
	BEGIN
		/* BLOCO DA FUNÇÃO ****************************************************/
		OPEN cSolicitacao(P_ID_DEM_RETORNO);
		FETCH cSolicitacao
			INTO rSolicitacao;
		CLOSE cSolicitacao;
    --
		/* Grava o cabecalho da resposta ******************************************/
		vTpTransacao    := 'DEMONSTRATIVO_ANALISE_CONTA';
		vNmXML          := 'demonstrativoAnaliseConta';
    --
		nIdTissMensagem := dbaps.FNC_TISS_INSERE_CABECALHO(P_ID_TISS_MENSAGEM, vTpTransacao, vNmXML, P_NR_REGISTRO_ANS, P_CNPJ_OPERADORA, P_CD_VERSAO, P_CD_PRESTADOR_OPERADORA, P_NR_CNPJ_PRESTADOR, P_NR_CPF_PRESTADOR, P_CD_GLOSA_CABECALHO, P_DS_GLOSA_CABECALHO, P_DS_GLOSA_CABECALHO);
		--
    SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
			INTO nIdTissDemAna
			FROM SYS.DUAL;
    --
    --
		/* Verifica se existe GLOSA NO CABEÇALHO DA MENSAGEM **********************/
		IF P_CD_GLOSA_CABECALHO IS NOT NULL THEN
			INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
				(CD_TISS_DEM_RETORNO_ERRO
				,CD_TISS_MENSAGEM
				,CD_MOTIVO_GLOSA
				,DS_MOTIVO_GLOSA)
			VALUES
				(nIdTissDemAna
				,nIdTissMensagem
				,P_CD_GLOSA_CABECALHO
				,P_DS_GLOSA_CABECALHO);
		ELSE
			/*************************************************************************
      * Se não há Glosa de Cabeçalho, verifica se existe alguma GLOSA NO
      * CORPO DA MENSAGEM.
      ************************************************************************/
			/* Valida se o prestador da solicitação é válido ************************/
			--
      bPrestadorValido := dbaps.FNC_VALIDA_PRESTADOR(rSolicitacao.cd_prestador_contratado, Nvl(rSolicitacao.NR_CNPJ_CONTRATADO, rSolicitacao.NR_CPF_CONTRATADO), Nvl(P_CD_MULTI_EMPRESA, DBAMV.PKG_MV2000.LE_EMPRESA));
			--
      IF bPrestadorValido = 'FALSE' THEN
				vCdGlosa := '1203';
				vDsGlosa := 'CÓDIGO PRESTADOR INVÁLIDO';
			END IF;
			/* Validar prestador em duplicade na mesma multi_empresa ****************/
			IF vCdGlosa IS NULL THEN
				BEGIN
					vCount       := 0;
					nCdPrestador := NULL;
          vTpCredenciado := NULL;
					nDsPrestador := NULL;
					nCdCnes      := NULL;
          --
					FOR rDadosPrestador IN cDadosPrestador(rSolicitacao.CD_PRESTADOR_CONTRATADO, NVL(rSolicitacao.nr_cnpj_contratado, rSolicitacao.nr_cpf_contratado), P_CD_MULTI_EMPRESA) LOOP
						nCdPrestador := rDadosPrestador.CD_PRESTADOR;
						nDsPrestador := rDadosPrestador.NM_PRESTADOR;
            vTpCredenciado := rDadosPrestador.tp_credenciamento;
						nCdCnes      := rDadosPrestador.CD_CNES;
						vCount       := vCount + 1;
					END LOOP;
          --
					IF vCount = 0 THEN
						vCdGlosa := '1203';
						vDsGlosa := 'CÓDIGO PRESTADOR INVÁLIDO/PRESTADOR INATIVO';
					END IF;
					IF vCount > 1 THEN
						vCdGlosa := '1203';
						vDsGlosa := 'PRESTADOR COM MAIS DE UM REGISTRO. ENTRE EM CONTATO COM A OPERADORA';
					END IF;
				EXCEPTION
					WHEN OTHERS THEN
						vCdGlosa := '1203';
						vDsGlosa := 'CODIGO DO PRESTADOR NAO CADASTRADO NA OPERADORA';
				END;
			END IF;
      --
			-- SE ENCONTROU GLOSA NO CORPO DA MENSAGEM
			IF vCdGlosa IS NOT NULL THEN
				INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
					(CD_TISS_DEM_RETORNO_ERRO
					,CD_TISS_MENSAGEM
					,CD_MOTIVO_GLOSA
					,DS_MOTIVO_GLOSA)
				VALUES
					(nIdTissDemAna
					,nIdTissMensagem
					,vCdGlosa
					,vDsGlosa);
			ELSE
      --


				/**********************************************************************
        *  Grava o cabeçalho do demonstrativo e os dados do prestador ********
        * - apenas no itens é que informamos o status de cada protocolo
        **********************************************************************/
				-- valores totais iniciam zerado até fazer somatório
				nSumVlInformadoGeral  := 0;
				nSumVlProcessadoGeral := 0;
				nSumVlLiberadoGeral   := 0;
				nSumVlGlosaGeral      := 0;
        --
				INSERT INTO DBAPS.TISS_DEM_ANA
					(ID
					,ID_PAI
					,NR_REGISTRO_ANS
					,NR_DEMONSTRATIVO
					,DS_OPERADORA
					,NR_CNPJ_OPERADORA
					,DT_EMISSAO
					,CD_PRESTADOR
					,DS_PRESTADOR
					,NR_CNES_PRESTADOR
					,VL_INFORMADO_GERAL
					,VL_PROCESSADO_GERAL
					,VL_LIBERADO_GERAL
					,VL_GLOSA_GERAL)
				VALUES
					(nIdTissDemAna -- ID
					,nIdTissMensagem -- ID_PAI
					,P_NR_REGISTRO_ANS -- NR_REGISTRO_ANS
					,nIdTissDemAna -- NR_DEMONSTRATIVO
					,P_DS_OPERADORA -- DS_OPERADORA
					,P_CNPJ_OPERADORA -- NR_CNPJ_OPERADORA
					,TO_CHAR(SYSDATE, 'YYYY-MM-DD') -- DT_EMISSAO
					,nCdPrestador -- CD_PRESTADOR <element name="dadosPrestador">
					,nDsPrestador -- DS_PRESTADOR
					,nCdCnes -- NR_CNES_PRESTADOR
					,nSumVlInformadoGeral -- VL_INFORMADO_GERAL
					,nSumVlProcessadoGeral -- VL_PROCESSADO_GERAL
					,nSumVlLiberadoGeral -- VL_LIBERADO_GERAL
					,nSumVlGlosaGeral -- VL_GLOSA_GERAL
					 );


        --
				-- buscando solicitações de protocolos (no máximo 30) - se existir...
				FOR rSolicitacaoProtocolo IN cSolicitacaoProtocolo(P_ID_DEM_RETORNO) LOOP
					/* Obtém dados do lote/protocolo em contas médicas ******************/
					SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
						INTO nIdTissDemAnaFatLot
						FROM SYS.DUAL;
					-- zerando variaveis
					vCdGlosa               := NULL;
					vDsGlosa               := NULL;
					dDtPagamento           := NULL;
					nCdFatura              := NULL;
					nNrLotePrestador       := 0;
					dDtEnvioLote           := rSolicitacao.DT_SOLICITACAO; -- DATA DA SOLICITACAO, POIS O XSD OBRIGA INFORMAR UMA DATA (BUG DA ANS)
					nCdProcoloCtaMed       := rSolicitacaoProtocolo.NR_PROTOCOLO; -- NUMERO DO PROTOCOLO INFORMADO PELO PRESTADOR
					vCdStatusProtocolo     := NULL;
					nVlInformadoProtocolo  := 0; -- VALOR INFORMADO
					nVlProcessadoProtocolo := 0; -- VALOR PROCESSADO
					nVlliberadoProtocolo   := 0; -- VALOR LIBERADO
					nVlGlosaProtocolo      := 0; -- VALOR GLOSADO
					-- BUSCANDO PROTOCOLO DE CONTAS MEDICAS
					OPEN cProtocoloCtamed(rSolicitacaoProtocolo.NR_PROTOCOLO);
					FETCH cProtocoloCtamed
						INTO rProtocoloCtamed;
					-- VERIFICA SE PROTOCOLO EXISTE
					IF cProtocoloCtamed%FOUND THEN
						dDtEnvioLote       := rProtocoloCtamed.DT_ENVIO_LOTE;
						nNrLotePrestador   := rProtocoloCtamed.NR_LOTE_PRESTADOR;
						vCdStatusProtocolo := rProtocoloCtamed.CD_STATUS_PROTOCOLO;
					ELSE
						vCdGlosa           := '5013';
						vDsGlosa           := 'PROTOCOLO NÃO ENCONTRADO';
						vCdStatusProtocolo := 7; -- 7 - Não Localizado
					END IF;
					-- VERIFICA SE PROTOCOLO PERTENCE AO PRESTADOR DA MSG TIS
					IF vCdGlosa IS NULL
						 AND rProtocoloCtamed.CD_PRESTADOR <> nCdPrestador THEN
						vCdGlosa           := '5013';
						vDsGlosa           := 'PROTOCOLO NÃO PERTENCE AO PRESTADOR DE CÓDIGO ' ||
																	nCdPrestador;
						vCdStatusProtocolo := 7; -- 7 - Não Localizado
					END IF;
					CLOSE cProtocoloCtamed;
					-- BUSCA DADOS DO PROTOCOLO (APENAS ITENS AUDITADOS)
					IF vCdGlosa IS NULL
						 AND rProtocoloCtamed.CD_STATUS_PROTOCOLO IN (3, 6) THEN
						-- LIBERADO PARA PAGAMENTO OU PAGAMENTO EFETUADO
						OPEN cProtocolo(rSolicitacaoProtocolo.NR_PROTOCOLO, nCdPrestador);
						FETCH cProtocolo
							INTO nCdFatura
									,nCdProcoloCtaMed
									,nNrLotePrestador
									,dDtEnvioLote
									,nVlInformadoProtocolo
									,nVlliberadoProtocolo -- VL_PAGO
									,nVlGlosaProtocolo
									,vCdStatusProtocolo
									,vCdGlosa
									,vDsGlosa;
						-- no presente momento, sistema nao trabalha com indicacao do valor processado... processa todo o informado
						nVlProcessadoProtocolo := nVlInformadoProtocolo;
						-- se protocolo nao foi encontrado... significa que view nao retornou nenhum item auditado -
						-- => evita problemas no nosso modulo de contas medicas, onde o protocolo exibe como liberado para pagamento, mas por algum
						-- problema na v_ctas_medicas os itens nao estao auditados
						IF cProtocolo%NOTFOUND THEN
							vCdStatusProtocolo := 2; -- em Análise
						END IF;
						CLOSE cProtocolo;
					END IF;
					nSumVlInformadoGeral  := nSumVlInformadoGeral +
																	 nVlInformadoProtocolo;
					nSumVlProcessadoGeral := nSumVlProcessadoGeral +
																	 nVlProcessadoProtocolo;
					nSumVlLiberadoGeral   := nSumVlLiberadoGeral +
																	 nVlliberadoProtocolo;
					nSumVlGlosaGeral      := nSumVlGlosaGeral + nVlGlosaProtocolo;
					/* INSERINDO DADOS DO PROTOCOLO INDEPENDENTE DO STATUS */
					INSERT INTO DBAPS.TISS_DEM_ANA_FAT_LOT
						(ID
						,CD_TISS_DEM_ANA
						,NR_LOTE
						,NR_PROTOCOLO
						,DT_ENVIO_LOTE
						,CD_MOTIVO_GLOSA_PROTOCOLO
						,DS_MOTIVO_GLOSA
						,CD_STATUS_PROTOCOLO
						,VL_INFORMADO_PROTOCOLO
						,VL_PROCESSADO_PROTOCOLO
						,VL_PROTOCOLO
						,VL_GLOSA_PROTOCOLO)
					VALUES
						(nIdTissDemAnaFatLot
						,nIdTissDemAna
						,nNrLotePrestador -- LOTE PRESTADOR
						,nCdProcoloCtaMed -- NR_PROTOCOLO
						,to_char(dDtEnvioLote, 'YYYY-MM-DD') -- DT_ENVIO_LOTE
						,vCdGlosa -- CD_MOTIVO_GLOSA_PROTOCOLO
						,vDsGlosa -- DS_MOTIVO_GLOSA
						,vCdStatusProtocolo -- CD_STATUS_PROTOCOLO
						,nVlInformadoProtocolo -- VL_INFORMADO_PROTOCOLO
						,nVlProcessadoProtocolo -- VL_PROCESSADO_PROTOCOLO
						,nVlliberadoProtocolo -- VL_PROTOCOLO
						,nVlGlosaProtocolo -- VL_GLOSA_PROTOCOLO
						 );
					/* relação de guias -- <element name="relacaoGuias" minOccurs="0" maxOccurs="unbounded"> */
					IF vCdGlosa IS NULL THEN
						/* Grava os dados das guias ***************************************/
						FOR rProtocoloCMGuia IN cProtocoloCmGuia(nCdProcoloCtaMed, nCdPrestador) LOOP
							-- BUSCANDO SEQUENCE PARA GUIAS DO PROTOCOLO
							SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
								INTO nIdTissDemAnaFatLotGui
								FROM SYS.DUAL;
							vHrEntrada := NULL;
							vHrSaida   := NULL;
							BEGIN
								vHrEntrada := To_Char(rProtocoloCMGuia.DT_INICIO_FAT, 'HH:MM:SS');
							EXCEPTION
								WHEN OTHERS THEN
									vHrEntrada := NULL;
							END;
							BEGIN
								vHrSaida := To_Char(rProtocoloCMGuia.DT_FIM_FAT, 'HH:MM:SS');
							EXCEPTION
								WHEN OTHERS THEN
									vHrSaida := NULL;
							END;
							-- <element name="dadosConta">
							--   <element name="dadosProtocolo" maxOccurs="unbounded">
							INSERT INTO DBAPS.TISS_DEM_ANA_FAT_LOT_GUI
								(ID
								,ID_PAI
								,NR_GUIA_PRESTADOR
								,NR_GUIA_OPERADORA
								,NR_SENHA
								,NM_BENEFICIARIO
								,NR_NUMERO_CARTEIRA
								,DT_INICIO_FAT
								,HR_INICIO_FAT
								,DT_FIM_FAT
								,HR_FIM_FAT
								,CD_STATUS_PROTOCOLO
								,VL_INFORMADO_GUIA
								,VL_PROCESSADO_GUIA
								,VL_LIBERADO_GUIA
								,VL_GLOSA_GUIA)
							VALUES
								(nIdTissDemAnaFatLotGui --ID
								,nIdTissDemAnaFatLot --ID_PAI
								,rProtocoloCMGuia.NR_GUIA_PRESTADOR --NR_GUIA_PRESTADOR
								,rProtocoloCMGuia.NR_GUIA_OPERADORA --NR_GUIA_OPERADORA
								,rProtocoloCMGuia.NR_SENHA --NR_SENHA
								,rProtocoloCMGuia.NM_BENEFICIARIO --NM_BENEFICIARIO
								,rProtocoloCMGuia.NR_CARTEIRA --NR_NUMERO_CARTEIRA
								,rProtocoloCMGuia.DT_INICIO_FAT --DT_INICIO_FAT
								,vHrEntrada --HR_INICIO_FAT
								,rProtocoloCMGuia.DT_FIM_FAT --DT_FIM_FAT
								,vHrSaida --HR_FIM_FAT
								,rProtocoloCMGuia.CD_STATUS_GUIA --CD_STATUS_PROTOCOLO
								,rProtocoloCMGuia.VL_INFORMADO --VL_INFORMADO_GUIA
								,rProtocoloCMGuia.VL_PROCESSADO --VL_PROCESSADO_GUIA
								,rProtocoloCMGuia.VL_LIBERADO --VL_LIBERADO_GUIA
								,rProtocoloCMGuia.VL_GLOSADO --VL_GLOSA_GUIA
								 );
							/*******************************************************************
              * @TODO: Em 06/08/2014 - Atualmente o Soul Saude não trabalha com glosas a
              * nível de guias (apenas a nível de procedimento) -
              * dessa forma os inserts na tabela de TISS_DEM_ANA_FAT_LOT_GUI_GLOS
              * não serão efetuados
              ********************************************************************/
							-- INSERT INTO TISS_DEM_ANA_FAT_LOT_GUI_GLOS....
							/* Procedimentos da guia **************************************/
							FOR rProtocoloCmGuiaProcedimento IN cProtocoloCmGuiaProcedimento(nCdProcoloCtaMed, rProtocoloCMGuia.NR_GUIA_OPERADORA, rProtocoloCMGuia.NR_GUIA_PRESTADOR, nCdPrestador) LOOP
								-- SEQUENCE
								SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
									INTO nIdTissDemAnaFatLotGuiPr
									FROM SYS.DUAL;
								-- Grava os dados dos procedimentos da guia
								vCdTissTabela := NULL;
								OPEN cTabela(rProtocoloCmGuiaProcedimento.CD_PROCEDIMENTO);
								FETCH cTabela
									INTO vCdTissTabela;
								CLOSE cTabela;
								INSERT INTO DBAPS.TISS_DEM_ANA_FAT_LOT_GUI_PR
									(ID
									,ID_PAI
									,DT_REALIZACAO
									,CD_TIPO_TABELA
									,CD_PROCEDIMENTO
									,DS_PROCEDIMENTO
									,CD_GRAU_PARTICIPACAO
									,VL_INFORMADO
									,QT_EXECUTADA
									,VL_PROCESSADO
									,VL_LIBERADO)
								VALUES
									(nIdTissDemAnaFatLotGuiPr
									,nIdTissDemAnaFatLotGui
									,rProtocoloCmGuiaProcedimento.DT_REALIZACAO
									,nvl(vCdTissTabela, '00')
									,rProtocoloCmGuiaProcedimento.CD_PROCEDIMENTO
									,rProtocoloCmGuiaProcedimento.DS_PROCEDIMENTO
									,rProtocoloCmGuiaProcedimento.CD_GRAU_PARTICIPACAO
									,rProtocoloCmGuiaProcedimento.VL_INFORMADO
									,rProtocoloCmGuiaProcedimento.QT_EXECUTADA
									,rProtocoloCmGuiaProcedimento.VL_INFORMADO -- O VALOR PROCESSADO FOI O INFORMADO PELO PRESTADOR POR COMPLETO
									,rProtocoloCmGuiaProcedimento.VL_LIBERADO);
								-- se procedimento possui glosa -- nosso sistema só trabalha com uma glosa
								-- por procedimento
								IF rProtocoloCmGuiaProcedimento.CD_TIPO_GLOSA IS NOT NULL THEN
									-- SEQUENCE
									SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
										INTO nIdTissDemAnaFatLotGuiPrGl
										FROM SYS.DUAL;
									-- Grava a glosa do procecimento
									OPEN cMotivoGlosa(rProtocoloCmGuiaProcedimento.CD_TIPO_GLOSA);
									FETCH cMotivoGlosa
										INTO rMotivoGlosa;
									CLOSE cMotivoGlosa;
									INSERT INTO DBAPS.TISS_DEM_ANA_FAT_LOT_GUI_PR_GL
										(ID
										,ID_PAI
										,CD_MOTIVO_GLOSA
										,DS_MOTIVO_GLOSA
										,VL_GLOSA)
									VALUES
										(nIdTissDemAnaFatLotGuiPrGl
										,nIdTissDemAnaFatLotGuiPr
										,rMotivoGlosa.CD_TISS
										,rMotivoGlosa.DS_MOTIVO
										,rProtocoloCmGuiaProcedimento.VL_GLOSA);
								END IF;
							END LOOP; --cProtocoloCmGuiaProcedimento
						END LOOP; --cProtocoloCmGuia
					END IF; --cProtocolo
				END LOOP; -- rSolicitacaoProtocolo (dados dos protocolos)
				-- atualizando totais
				IF nIdTissDemAna IS NOT NULL THEN
					UPDATE DBAPS.TISS_DEM_ANA
						 SET VL_INFORMADO_GERAL  = nSumVlInformadoGeral
								,VL_PROCESSADO_GERAL = nSumVlProcessadoGeral
								,VL_LIBERADO_GERAL   = nSumVlLiberadoGeral
								,VL_GLOSA_GERAL      = nSumVlGlosaGeral
					 WHERE ID = nIdTissDemAna;
				END IF;
			END IF; -- vCdGlosa IS NULL (corpo da mensagem)
		END IF; -- P_CD_GLOSA_CABECALHO IS NOT NULL
		RETURN nIdTissMensagem;
	END; -- gravarRespostaDemAnalise
	--
	--
	/*****************************************************************************
  * Grava uma resposta para o DEMONSTRATIVO de PAGAMENTO
  ****************************************************************************/
	FUNCTION gravarRespostaDemPagamento(P_ID_DEM_RETORNO         IN NUMBER
																		 ,P_ID_TISS_MENSAGEM       IN NUMBER
																		 ,P_NR_REGISTRO_ANS        IN VARCHAR2
																		 ,P_CNPJ_OPERADORA         IN VARCHAR2
																		 ,P_DS_OPERADORA           IN VARCHAR2
																		 ,P_CD_VERSAO              IN VARCHAR2
																		 ,P_CD_PRESTADOR_OPERADORA IN VARCHAR2
																		 ,P_NR_CNPJ_PRESTADOR      IN VARCHAR2
																		 ,P_NR_CPF_PRESTADOR       IN VARCHAR2
																		 ,P_CD_GLOSA_CABECALHO     IN VARCHAR2
																		 ,P_DS_GLOSA_CABECALHO     IN VARCHAR2
																		 ,P_CD_MULTI_EMPRESA       IN NUMBER)
		RETURN NUMBER IS
		--
		--
		/* Declaração dos cursores ************************************************/
		/* Cursor principal que obtém as datas agrupadas dos pagamentos ***********/
		CURSOR cPgtoPorData(P_CD_MULTI_EMPRESA IN NUMBER
											 ,P_CD_PRESTADOR     IN NUMBER
											 ,P_DT_COMPETENCIA   IN VARCHAR2
											 ,P_DT_PAGAMENTO     IN DATE) IS
			SELECT PCP.DT_PAGAMENTO
				FROM DBAPS.REPASSE_PRESTADOR RP
						,DBAPS.FATURA            F
						,DBAMV.CON_PAG           CP
						,DBAMV.ITCON_PAG         ICP
						,DBAMV.PAGCON_PAG        PCP
			 WHERE RP.CD_FATURA = F.CD_FATURA
				 AND CP.CD_CON_PAG = ICP.CD_CON_PAG
				 AND RP.CD_CON_PAG = CP.CD_CON_PAG
				 AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
				 AND RP.CD_PRESTADOR = P_CD_PRESTADOR
				 AND F.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
				 AND (P_DT_PAGAMENTO IS NULL AND
						 TO_CHAR(trunc(PCP.DT_PAGAMENTO), 'MMYYYY') = P_DT_COMPETENCIA OR
						 nvl(P_DT_PAGAMENTO, '*') <> '*' AND
						 TRUNC(PCP.DT_PAGAMENTO) = P_DT_PAGAMENTO)
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'N'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PCP.DT_PAGAMENTO
			UNION ALL
      --NOVO FORMATO 2018 EM DIANTE
			SELECT PCP.DT_PAGAMENTO
				FROM DBAPS.REPASSE_PRESTADOR     RP
            ,DBAPS.PRESTADOR             P
						,DBAMV.CON_PAG               CP
						,DBAMV.ITCON_PAG             ICP
						,DBAMV.PAGCON_PAG            PCP
			 WHERE RP.CD_PRESTADOR = P.CD_PRESTADOR
         AND P.TP_CREDENCIAMENTO NOT IN ('P')
				 AND CP.CD_CON_PAG = ICP.CD_CON_PAG
				 AND RP.CD_CON_PAG = CP.CD_CON_PAG
				 AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
				 AND RP.CD_PRESTADOR = P_CD_PRESTADOR
				 AND CP.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
				 AND (P_DT_PAGAMENTO IS NULL AND TO_CHAR(trunc(PCP.DT_PAGAMENTO), 'MMYYYY') = P_DT_COMPETENCIA
            OR nvl(P_DT_PAGAMENTO, '*') <> '*' AND TRUNC(PCP.DT_PAGAMENTO) = P_DT_PAGAMENTO)
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'S'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PCP.DT_PAGAMENTO
       UNION ALL
       --NOVO FORMATO 2018 EM DIANTE
			SELECT PP.DT_COMPETENCIA
				FROM DBAPS.REPASSE_PRESTADOR     RP
            ,DBAPS.PRESTADOR              P
						,DBAPS.PAGAMENTO_PRESTADOR   PP
			 WHERE RP.CD_PAGAMENTO_PRESTADOR = PP.CD_PAGAMENTO_PRESTADOR
         AND RP.CD_PRESTADOR = P.CD_PRESTADOR
         AND P.TP_CREDENCIAMENTO IN ('P')
				 AND RP.CD_PRESTADOR = P_CD_PRESTADOR
				 AND P.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
				 AND (
             P_DT_PAGAMENTO IS NULL AND TO_CHAR(trunc(PP.DT_COMPETENCIA), 'MMYYYY') = P_DT_COMPETENCIA
             OR (
              nvl(P_DT_PAGAMENTO, '*') <> '*' AND TO_CHAR(trunc(PP.DT_COMPETENCIA), 'MMYYYY') = To_Char(P_DT_PAGAMENTO, 'MMYYYY')
            )
         )
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'S'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PP.DT_COMPETENCIA;
		--
		/* SELECT PCP.DT_PAGAMENTO
           FROM DBAPS.REPASSE_PRESTADOR RP,
                DBAPS.FATURA F,
                DBAMV.CON_PAG CP,
                DBAMV.ITCON_PAG ICP,
                DBAMV.PAGCON_PAG PCP
          WHERE RP.CD_FATURA = F.CD_FATURA
            AND CP.CD_CON_PAG = ICP.CD_CON_PAG
            AND RP.CD_CON_PAG = CP.CD_CON_PAG
            AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
            AND RP.CD_PRESTADOR = P_CD_PRESTADOR
            AND F.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
            AND ( P_DT_PAGAMENTO IS NULL AND TO_CHAR(trunc(PCP.DT_PAGAMENTO), 'MMYYYY') = P_DT_COMPETENCIA
                  OR
                  nvl(P_DT_PAGAMENTO,'*') <> '*' AND TRUNC(PCP.DT_PAGAMENTO) = P_DT_PAGAMENTO
                )
      AND EXISTS
     (SELECT 1
              FROM DBAPS.MVS_CONFIGURACAO
             WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
               AND VALOR = 'N'
               AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
          GROUP BY PCP.DT_PAGAMENTO
    UNION ALL
         SELECT PCP.DT_PAGAMENTO
           FROM DBAPS.REPASSE_PRESTADOR RP,
                DBAPS.FATURA F,
                DBAMV.CON_PAG CP,
                DBAMV.ITCON_PAG ICP,
                DBAMV.PAGCON_PAG PCP
          WHERE CP.CD_CON_PAG = ICP.CD_CON_PAG
            AND RP.CD_CON_PAG = CP.CD_CON_PAG
            AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
            AND RP.CD_PRESTADOR = P_CD_PRESTADOR
            AND F.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
            AND ( P_DT_PAGAMENTO IS NULL AND TO_CHAR(trunc(PCP.DT_PAGAMENTO), 'MMYYYY') >= P_DT_COMPETENCIA
                  OR
                  nvl(P_DT_PAGAMENTO,'*') <> '*' AND TRUNC(PCP.DT_PAGAMENTO) >= P_DT_PAGAMENTO
                )
      AND EXISTS
     (SELECT 1
              FROM DBAPS.MVS_CONFIGURACAO
             WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
               AND VALOR = 'S'
               AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
          GROUP BY PCP.DT_PAGAMENTO;
    */

		--
		--
		/* Obtém as PKs dos Itens de Pagamento por Data ***************************/
		CURSOR cItensPagamento(P_DT_PAGAMENTO     IN DATE
													,P_CD_PRESTADOR     IN NUMBER
													,P_CD_MULTI_EMPRESA IN NUMBER) IS

			SELECT PCP.CD_ITCON_PAG, CP.CD_CON_PAG
				FROM DBAPS.REPASSE_PRESTADOR RP
						,DBAPS.FATURA            F
						,DBAMV.CON_PAG           CP
						,DBAMV.ITCON_PAG         ICP
						,DBAMV.PAGCON_PAG        PCP
			 WHERE RP.CD_FATURA = F.CD_FATURA
				 AND CP.CD_CON_PAG = ICP.CD_CON_PAG
				 AND RP.CD_CON_PAG = CP.CD_CON_PAG
				 AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
				 AND RP.CD_PRESTADOR IN
						 (SELECT CD_PRESTADOR
								FROM DBAPS.PRESTADOR
							 WHERE CD_PRESTADOR_GUIA_WEB = P_CD_PRESTADOR)
				 AND F.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
				 AND PCP.DT_PAGAMENTO = P_DT_PAGAMENTO
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'N'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PCP.CD_ITCON_PAG,CP.CD_CON_PAG
			--
			UNION ALL
			--
			SELECT PCP.CD_ITCON_PAG, CP.CD_CON_PAG
				FROM DBAPS.REPASSE_PRESTADOR     RP
						,DBAMV.CON_PAG               CP
						,DBAMV.ITCON_PAG             ICP
						,DBAMV.PAGCON_PAG            PCP
			 WHERE RP.CD_CON_PAG = CP.CD_CON_PAG
         AND CP.CD_CON_PAG = ICP.CD_CON_PAG
				 AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
				 AND CP.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
				 AND RP.CD_PRESTADOR IN
						 (SELECT CD_PRESTADOR
								FROM DBAPS.PRESTADOR
							 WHERE CD_PRESTADOR_GUIA_WEB = P_CD_PRESTADOR)
				 AND PCP.DT_PAGAMENTO = P_DT_PAGAMENTO
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'S'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PCP.CD_ITCON_PAG,CP.CD_CON_PAG;
		--
		--
		/*    SELECT PCP.CD_ITCON_PAG
      FROM DBAPS.REPASSE_PRESTADOR RP,
           DBAPS.FATURA            F,
           DBAMV.CON_PAG           CP,
           DBAMV.ITCON_PAG         ICP,
           DBAMV.PAGCON_PAG        PCP
     WHERE RP.CD_FATURA = F.CD_FATURA
       AND CP.CD_CON_PAG = ICP.CD_CON_PAG
       AND RP.CD_CON_PAG = CP.CD_CON_PAG
       AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
       AND RP.CD_PRESTADOR IN
           (SELECT CD_PRESTADOR
              FROM DBAPS.PRESTADOR
             WHERE CD_PRESTADOR_GUIA_WEB = P_CD_PRESTADOR)
       AND F.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
       AND PCP.DT_PAGAMENTO = P_DT_PAGAMENTO
       AND EXISTS (SELECT 1
              FROM DBAPS.MVS_CONFIGURACAO
             WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
               AND VALOR = 'N'
               AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
     GROUP BY PCP.CD_ITCON_PAG
    UNION ALL
    SELECT PCP.CD_ITCON_PAG
      FROM DBAPS.REPASSE_PRESTADOR RP,
           DBAPS.FATURA            F,
           DBAMV.CON_PAG           CP,
           DBAMV.ITCON_PAG         ICP,
           DBAMV.PAGCON_PAG        PCP
     WHERE CP.CD_CON_PAG = ICP.CD_CON_PAG
       AND RP.CD_CON_PAG = CP.CD_CON_PAG
       AND PCP.CD_ITCON_PAG = ICP.CD_ITCON_PAG
       AND RP.CD_PRESTADOR IN
           (SELECT CD_PRESTADOR
              FROM DBAPS.PRESTADOR
             WHERE CD_PRESTADOR_GUIA_WEB = P_CD_PRESTADOR)
       AND F.CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA
       AND PCP.DT_PAGAMENTO = P_DT_PAGAMENTO
       AND EXISTS (SELECT 1
              FROM DBAPS.MVS_CONFIGURACAO
             WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
               AND VALOR = 'S'
               AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
     GROUP BY PCP.CD_ITCON_PAG;*/

		--
		--
		/*************************************************************************
    * Obtém a forma de pagamento do item de pagamento:
    * A versão do TISS 3.02 permite informar apenas um Tipo de Pagamento por Data.
    * Enquanto o sistema permite vários pagamentos por data. Dessa forma, será
    * informado a primeira forma de pagamento encontrada no sistema.
    * TODO: o decode não contempla todo o DE-PARA do sistema com o tiss.
    *  <!--1 - Depósito/transferência bancária-->
    *  <!--2 - Carteira-->
    *  <!--3 - Boleto Bancário / DDA-->
    *  <!--4 - Dinheiro/cheque-->
    ************************************************************************/
		CURSOR cFormaPgt(P_CD_ITCON_PAG IN NUMBER) IS
			SELECT Decode(PCP.TP_PAGAMENTO, '5', '1', '8', '1', '1', '3', '2', '3', '3', '4', '4', '4', NULL) TP_PAGAMENTO
				FROM DBAMV.PAGCON_PAG PCP
			 WHERE PCP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND ROWNUM = 1
			 ORDER BY PCP.CD_PAGCON_PAG;
		--
		--
		/* Obtém o código do banco onde foi realizado o pagamento *****************/
		CURSOR cCdBanco(P_CD_ITCON_PAG IN NUMBER) IS
			SELECT PCP.CD_BANCO_FORN CD_BANCO
				FROM DBAMV.PAGCON_PAG PCP
			 WHERE PCP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND PCP.CD_BANCO_FORN IS NOT NULL
			 GROUP BY PCP.CD_BANCO_FORN
			UNION ALL
			SELECT B.CD_BANCO
				FROM DBAMV.CON_PAG    CP
						,DBAMV.ITCON_PAG  ICP
						,DBAMV.FORNECEDOR F
						,DBAMV.BANCO      B
			 WHERE ICP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND ICP.CD_CON_PAG = CP.CD_CON_PAG
				 AND CP.CD_FORNECEDOR = F.CD_FORNECEDOR
				 AND F.CD_BANCO = B.CD_BANCO
				 AND B.CD_BANCO IS NOT NULL
			 GROUP BY B.CD_BANCO;
		--
		--
		/* Obtém o código da agência onde foi realizado o pagamento ***************/
		CURSOR cCdAgencia(P_CD_ITCON_PAG IN NUMBER) IS
			SELECT PCP.CD_AGENCIA_FORN CD_AGENCIA
				FROM DBAMV.PAGCON_PAG PCP
			 WHERE PCP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND PCP.CD_AGENCIA_FORN IS NOT NULL
			 GROUP BY PCP.CD_AGENCIA_FORN
			UNION ALL
			SELECT F.CD_AGENCIA CD_AGENCIA
				FROM DBAMV.CON_PAG    CP
						,DBAMV.ITCON_PAG  ICP
						,DBAMV.FORNECEDOR F
			 WHERE ICP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND ICP.CD_CON_PAG = CP.CD_CON_PAG
				 AND CP.CD_FORNECEDOR = F.CD_FORNECEDOR
				 AND F.CD_AGENCIA IS NOT NULL
			 GROUP BY F.CD_AGENCIA;
		--
		--
		/* Obtém o número da conta onde foi realizado o pagamento *****************/
		CURSOR cNrConta(P_CD_ITCON_PAG IN NUMBER) IS
			SELECT PCP.NR_CONTA_FORN NR_CONTA
				FROM DBAMV.PAGCON_PAG PCP
			 WHERE PCP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND PCP.NR_CONTA_FORN IS NOT NULL
			 GROUP BY PCP.NR_CONTA_FORN
			UNION ALL
			SELECT F.NR_CONTA NR_CONTA
				FROM DBAMV.CON_PAG    CP
						,DBAMV.ITCON_PAG  ICP
						,DBAMV.FORNECEDOR F
			 WHERE ICP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND ICP.CD_CON_PAG = CP.CD_CON_PAG
				 AND CP.CD_FORNECEDOR = F.CD_FORNECEDOR
				 AND F.NR_CONTA IS NOT NULL
			 GROUP BY F.NR_CONTA;
		--
		--
		/* Obtém o número do cheque ***********************************************/
		CURSOR cNrCheque(P_CD_ITCON_PAG IN NUMBER) IS
			SELECT PCP.CD_CHEQUE
				FROM DBAMV.PAGCON_PAG PCP
			 WHERE PCP.CD_ITCON_PAG = P_CD_ITCON_PAG
				 AND PCP.CD_CHEQUE IS NOT NULL
			 GROUP BY PCP.CD_CHEQUE;
		--
		--
		/* Obtém o resumo do pagamento ********************************************/
		CURSOR cDadosResumoPgt(P_CD_REPASSE_PRESTADOR     IN NUMBER
													,P_CD_MULTI_EMPRESA IN NUMBER) IS

			SELECT PRO.DT_ENVIO_LOTE DT_PROTOCOLO
						,LOT.CD_PROTOCOLO_CTAMED NR_PROTOCOLO
						,PRO.NR_LOTE_PRESTADOR NR_LOTE
						,(SELECT SUM(FNC_CHAR2NUMBER(V.VL_TOTAL_PROCEDIMENTO))
								FROM DBAPS.V_TISS_LOTE_GUIA V
							 WHERE V.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED) VL_INFORMADO
						,SUM(CTA.VL_TOTAL_PAGO) VL_LIBERADO
						,SUM(CTA.VL_TOTAL_GLOSADO) VL_GLOSA

				FROM DBAPS.REPASSE_PRESTADOR RP
						,DBAPS.LOTE              LOT
						,DBAPS.PROTOCOLO_CTAMED  PRO
						,DBAPS.V_CTAS_MEDICAS    CTA
			 WHERE RP.CD_FATURA = PRO.CD_FATURA
				 AND LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED
				 AND CTA.CD_LOTE = LOT.CD_LOTE
				 AND RP.CD_REPASSE_PRESTADOR = P_CD_REPASSE_PRESTADOR
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'N'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PRO.DT_ENVIO_LOTE
							 ,LOT.CD_PROTOCOLO_CTAMED
							 ,PRO.CD_PROTOCOLO_CTAMED
							 ,PRO.NR_LOTE_PRESTADOR
			--
			UNION ALL
			--
			SELECT Nvl(PRO.DT_ENVIO_LOTE, LOT.DT_LOTE)  DT_PROTOCOLO
						,Nvl(LOT.CD_PROTOCOLO_CTAMED, LOT.CD_LOTE) NR_PROTOCOLO
						,Nvl(PRO.NR_LOTE_PRESTADOR, LOT.CD_LOTE) NR_LOTE
						,Nvl((SELECT SUM(FNC_CHAR2NUMBER(V.VL_TOTAL_PROCEDIMENTO))
								FROM DBAPS.V_TISS_LOTE_GUIA V
							 WHERE V.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED),SUM(CTA.VL_TOTAL_PAGO)) VL_INFORMADO
						,SUM(CTA.VL_TOTAL_PAGO) VL_LIBERADO
						,SUM(CTA.VL_TOTAL_GLOSADO) VL_GLOSA
				FROM DBAPS.REPASSE_PRESTADOR RP
						,DBAPS.LOTE              LOT
						,DBAPS.PROTOCOLO_CTAMED  PRO
						,DBAPS.V_CTAS_MEDICAS    CTA
			 WHERE RP.CD_REPASSE_PRESTADOR = CTA.CD_REPASSE_PRESTADOR
				 AND CTA.CD_LOTE = LOT.CD_LOTE
         AND LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED (+)
         AND CTA.CD_REPASSE_PRESTADOR = P_CD_REPASSE_PRESTADOR
				 AND EXISTS
			 (SELECT 1
								FROM DBAPS.MVS_CONFIGURACAO
							 WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
								 AND VALOR = 'S'
								 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
			 GROUP BY PRO.DT_ENVIO_LOTE
							 ,LOT.CD_PROTOCOLO_CTAMED
               ,LOT.CD_LOTE
               ,LOT.DT_LOTE
							 ,PRO.CD_PROTOCOLO_CTAMED
							 ,PRO.NR_LOTE_PRESTADOR
               ,RP.CD_REPASSE_PRESTADOR;
		--
		--
		/*  SELECT PRO.DT_ENVIO_LOTE DT_PROTOCOLO,
             LOT.CD_PROTOCOLO_CTAMED NR_PROTOCOLO,
             PRO.NR_LOTE_PRESTADOR NR_LOTE,
             (SELECT SUM(FNC_CHAR2NUMBER(V.VL_TOTAL_PROCEDIMENTO))
                FROM DBAPS.V_TISS_LOTE_GUIA V
               WHERE V.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED) VL_INFORMADO,
             SUM(CTA.VL_TOTAL_PAGO) VL_LIBERADO,
             SUM(CTA.VL_TOTAL_GLOSADO) VL_GLOSA
        FROM DBAPS.REPASSE_PRESTADOR RP,
             DBAPS.LOTE              LOT,
             DBAPS.PROTOCOLO_CTAMED  PRO,
             DBAPS.V_CTAS_MEDICAS    CTA,
             DBAMV.ITCON_PAG         ICP
       WHERE RP.CD_FATURA = PRO.CD_FATURA
         AND LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED
         AND CTA.CD_LOTE = LOT.CD_LOTE
         AND ICP.CD_CON_PAG = RP.CD_CON_PAG
         AND ICP.CD_ITCON_PAG = P_CD_ITCON_PAG
         AND EXISTS
       (SELECT 1
                FROM DBAPS.MVS_CONFIGURACAO
               WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
                 AND VALOR = 'N'
                 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
       GROUP BY PRO.DT_ENVIO_LOTE,
                LOT.CD_PROTOCOLO_CTAMED,
                PRO.CD_PROTOCOLO_CTAMED,
                PRO.NR_LOTE_PRESTADOR
      UNION ALL
      SELECT PRO.DT_ENVIO_LOTE DT_PROTOCOLO,
             LOT.CD_PROTOCOLO_CTAMED NR_PROTOCOLO,
             PRO.NR_LOTE_PRESTADOR NR_LOTE,
             (SELECT SUM(FNC_CHAR2NUMBER(V.VL_TOTAL_PROCEDIMENTO))
                FROM DBAPS.V_TISS_LOTE_GUIA V
               WHERE V.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED) VL_INFORMADO,
             SUM(CTA.VL_TOTAL_PAGO) VL_LIBERADO,
             SUM(CTA.VL_TOTAL_GLOSADO) VL_GLOSA
        FROM DBAPS.REPASSE_PRESTADOR RP,
             DBAPS.LOTE              LOT,
             DBAPS.PROTOCOLO_CTAMED  PRO,
             DBAPS.V_CTAS_MEDICAS    CTA,
             DBAMV.ITCON_PAG         ICP
       WHERE CTA.CD_FATURA = PRO.CD_FATURA
         AND LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED
         AND CTA.CD_LOTE = LOT.CD_LOTE
         AND ICP.CD_CON_PAG = RP.CD_CON_PAG
         AND RP.CD_REPASSE_PRESTADOR = CTA.CD_REPASSE_PRESTADOR
         AND ICP.CD_ITCON_PAG = P_CD_ITCON_PAG
         AND EXISTS
       (SELECT 1
                FROM DBAPS.MVS_CONFIGURACAO
               WHERE CHAVE = 'CONTMED_FOLHA_PGTO'
                 AND VALOR = 'S'
                 AND CD_MULTI_EMPRESA = P_CD_MULTI_EMPRESA)
       GROUP BY PRO.DT_ENVIO_LOTE,
                LOT.CD_PROTOCOLO_CTAMED,
                PRO.CD_PROTOCOLO_CTAMED,
                PRO.NR_LOTE_PRESTADOR;
    */
		--
		--
		/*************************************************************************
    *  Obtém o credito debito por data
    *
    * @todo: o tipo de debito/credito está fixo como '08' pois o nosso sistema não
    * classifica os lançamentos.
    * Sugestão: Existe um cd_item_despesa que é cadastrado pela operadora mas hj
    * não existe como fazer de/para sem um tipo na tabela DBAPS.ITEM_DESPESA
    *
    ********************************************/
		CURSOR cCredDebitoPorData(P_CD_ITCON_PAG IN NUMBER) IS
			SELECT DECODE(PCD.TP_LANCAMENTO, 'C', 1, 'D', 2, NULL) TP_INDICADOR
						,'08' TP_DEBITO_CREDITO
						,PCD.DS_OBSERVACAO
						,PCD.VL_LANCAMENTO
				FROM DBAPS.PRESTADOR_CREDITO_DEBITO PCD
			 WHERE CD_FATURA IN
						 (SELECT PRO.CD_FATURA
								FROM DBAPS.REPASSE_PRESTADOR RP
										,DBAPS.LOTE              LOT
										,DBAPS.PROTOCOLO_CTAMED  PRO
										,DBAPS.V_CTAS_MEDICAS    CTA
										,DBAMV.ITCON_PAG         ICP
							 WHERE RP.CD_FATURA = PRO.CD_FATURA
								 AND LOT.CD_PROTOCOLO_CTAMED = PRO.CD_PROTOCOLO_CTAMED
								 AND CTA.CD_LOTE = LOT.CD_LOTE
								 AND ICP.CD_CON_PAG = RP.CD_CON_PAG
								 AND ICP.CD_ITCON_PAG = P_CD_ITCON_PAG
							 GROUP BY PRO.CD_FATURA);
		--
		--
		/* Declaração das variáveis ***********************************************/
		--cursores
		rPgtoPorData    cPgtoPorData%ROWTYPE;
		rItensPagamento DBAMV.PAGCON_PAG%ROWTYPE;
		rDadosResumoPgt cDadosResumoPgt%ROWTYPE;
		-- PK's
		nIdTissDemPgt           DBAPS.TISS_DEM_PGT.ID%TYPE;
		nIdTissDemPgtItem       DBAPS.TISS_DEM_PGT_ITEM.CD_TISS_DEM_PGT_ITEM%TYPE;
		nIdTissDemPgtItemResumo DBAPS.TISS_DEM_PGT_ITEM_RESUMO.CD_TISS_DEM_PGT_ITEM_RESUMO%TYPE;
		-- totais por item (data)
		nTotalInformadoPorData NUMBER(11, 2);
		nTotaLiberadoPorData   NUMBER(11, 2);
		nTotalGlosaPorData     NUMBER(11, 2);
		nTotalDebitosPorData   NUMBER(11, 2);
		nTotalCreditosPorData  NUMBER(11, 2);
		-- totais gerais (demonstrativo)
		nTotalInformadoPorDataDem NUMBER(11, 2);
		nTotaLiberadoPorDataDem   NUMBER(11, 2);
		nTotalGlosaPorDataDem     NUMBER(11, 2);
		nTotalDebitoPorDataDem    NUMBER(11, 2);
		nTotalCreditoPorDataDem   NUMBER(11, 2);
		-- regra de negocio
		vFormaPgt      VARCHAR2(2);
		nCdBanco       NUMBER(10);
		vCdAgencia     VARCHAR2(10);
		vNrConta       VARCHAR2(20);
		dDtPagamento   DATE;
		vDtCompetencia VARCHAR2(10);
		-- auxiliares
		nCountPagamentos    NUMBER(10);
		nCountPgtPorData    NUMBER(10);
		nCountCdBanco       NUMBER(10);
		snIntegraFinanceiro VARCHAR2(1);
		i                   NUMBER;
		dTeste              DATE;
		--
		-- colecao de debito/credito
		TYPE rcCredDeb IS RECORD(
			TP_INDICADOR      NUMBER,
			TP_DEBITO_CREDITO VARCHAR2(3),
			DS_OBSERVACAO     VARCHAR2(500),
			VL_LANCAMENTO     NUMBER);
		--
		TYPE tCredDeb IS TABLE OF rcCredDeb INDEX BY BINARY_INTEGER;
		--
		aCredDeb tCredDeb;
		--
		--
	BEGIN
		--
		--
		OPEN cSolicitacao(rTissMensagem.ID_DEM_RETORNO);
		FETCH cSolicitacao
			INTO rSolicitacao;
		CLOSE cSolicitacao;
		--

		/* Grava o cabecalho da resposta ******************************************/
		vTpTransacao    := 'DEMONSTRATIVO_PAGAMENTO';
		vNmXML          := 'demonstrativoPagamento';
		nIdTissMensagem := dbaps.FNC_TISS_INSERE_CABECALHO(P_ID_TISS_MENSAGEM, vTpTransacao, vNmXML, P_NR_REGISTRO_ANS, P_CNPJ_OPERADORA, P_CD_VERSAO, P_CD_PRESTADOR_OPERADORA, P_NR_CNPJ_PRESTADOR, P_NR_CPF_PRESTADOR, P_CD_GLOSA_CABECALHO, P_DS_GLOSA_CABECALHO, P_DS_GLOSA_CABECALHO);
		--
		SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
			INTO nIdTissDemPgt
			FROM SYS.DUAL;
		--
		--
		/* Verifica se existe GLOSA NO CABEÇALHO DA MENSAGEM **********************/
		IF P_CD_GLOSA_CABECALHO IS NOT NULL THEN
			--
			INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
				(CD_TISS_DEM_RETORNO_ERRO
				,CD_TISS_MENSAGEM
				,CD_MOTIVO_GLOSA
				,DS_MOTIVO_GLOSA)
			VALUES
				(nIdTissDemPgt
				,nIdTissMensagem
				,P_CD_GLOSA_CABECALHO
				,P_DS_GLOSA_CABECALHO);
			--
		ELSE
			-- IF P_CD_GLOSA_CABECALHO IS NOT NULL THEN
			--
			/*************************************************************************
      * Se não há Glosa no Cabeçalho, verifica se existe alguma GLOSA NO
      * CORPO DA MENSAGEM.
      ***********************************************************************/
			/* Valida se o prestador da solicitação é válido ************************/
			IF vCdGlosa IS NULL THEN
				--
				bPrestadorValido := dbaps.FNC_VALIDA_PRESTADOR(rSolicitacao.cd_prestador_contratado, nvl(rSolicitacao.NR_CNPJ_CONTRATADO, rSolicitacao.NR_CPF_CONTRATADO), Nvl(P_CD_MULTI_EMPRESA, DBAMV.PKG_MV2000.LE_EMPRESA));
				--
				IF bPrestadorValido = 'FALSE' THEN
					vCdGlosa := '1203';
					vDsGlosa := 'CÓDIGO PRESTADOR INVÁLIDO';
					--
				END IF;
				--
			END IF; --IF vCdGlosa IS NULL THEN
			--
			-- por competencia
			IF rSolicitacao.DT_COMPETENCIA IS NOT NULL THEN
				--
				-- checando se data é valida
				BEGIN
					SELECT TO_DATE(rSolicitacao.DT_COMPETENCIA || '01', 'YYYYMMDD')
						INTO dTeste
						FROM DUAL;
					vDtCompetencia := SubStr(rSolicitacao.DT_COMPETENCIA, 5, 2) ||
														SubStr(rSolicitacao.DT_COMPETENCIA, 1, 4);
				EXCEPTION
					WHEN OTHERS THEN
						vCdGlosa := '5013';
						vDsGlosa := 'DATA DE COMPETENCIA SOLICITADA INVÁLIDA';
				END;
				--
			END IF; --IF rSolicitacao.DT_COMPETENCIA IS NOT NULL THEN
			--
			-- por data
			IF rSolicitacao.DT_PAGAMENTO IS NOT NULL THEN
				BEGIN
					dDtPagamento := trunc(to_date(rSolicitacao.DT_PAGAMENTO));
				EXCEPTION
					WHEN OTHERS THEN
						vCdGlosa := '5013';
						vDsGlosa := 'DATA DE PAGAMENTO SOLICITADA INVÁLIDA';
				END;
			END IF; --IF rSolicitacao.DT_PAGAMENTO IS NOT NULL THEN
			--
			--
			/* Validar prestador em duplicade na mesma multi_empresa ****************/
			IF vCdGlosa IS NULL THEN
				--
				BEGIN
					--
					vCount       := 0;
					nCdPrestador := NULL;
					nDsPrestador := NULL;
          vTpCredenciado := NULL;
					nCdCnes      := NULL;
					FOR rPrestador IN cDadosPrestador(rSolicitacao.CD_PRESTADOR_CONTRATADO, NVL(rSolicitacao.nr_cnpj_contratado, rSolicitacao.nr_cpf_contratado), P_CD_MULTI_EMPRESA) LOOP
						--
						vCount       := vCount + 1;
						nCdPrestador := rPrestador.CD_PRESTADOR;
						nDsPrestador := rPrestador.NM_PRESTADOR;
            vTpCredenciado := rPrestador.tp_credenciamento;
						nCdCnes      := rPrestador.CD_CNES;
						--
					END LOOP;
					--
					--
					IF vCount = 0 THEN
						vCdGlosa := '1203';
						vDsGlosa := 'CÓDIGO PRESTADOR INVÁLIDO/PRESTADOR INATIVO';
					END IF;
					--
					IF vCount > 1 THEN
						vCdGlosa := '1203';
						vDsGlosa := 'CÓDIGO PRESTADOR INVÁLIDO/PRESTADOR COM MAIS DE UM REGISTRO. ENTRE EM CONTATO COM A OPERADORA';
					END IF;
					--
				EXCEPTION
					WHEN OTHERS THEN
						vCdGlosa := '1203';
						vDsGlosa := 'CODIGO DO PRESTADOR NAO CADASTRADO NA OPERADORA';
				END;
				--
				--
			END IF; --IF vCdGlosa IS NULL THEN
			--

			-- se houve glosa no corpo da mensagem
			IF vCdGlosa IS NOT NULL THEN
				--
				INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
					(CD_TISS_DEM_RETORNO_ERRO
					,CD_TISS_MENSAGEM
					,CD_MOTIVO_GLOSA
					,DS_MOTIVO_GLOSA)
				VALUES
					(nIdTissDemPgt
					,nIdTissMensagem
					,vCdGlosa
					,vDsGlosa);
				--
				--
			ELSE
				--IF vCdGlosa IS NOT NULL THEN
				--
				-- solicitação está 'OK'
				/* Verificando se sistema possui integração com financeiro *************/
				snIntegraFinanceiro := 'S'; -- default é sim
				SELECT SN_INTEGRA_CON_PAG
					INTO snIntegraFinanceiro
					FROM DBAPS.PLANO_DE_SAUDE
				 WHERE ID = 1;
				--
				INSERT INTO DBAPS.TISS_DEM_PGT
					(ID
					,ID_PAI
					,NR_REGISTRO_ANS
					,NR_DEMONSTRATIVO
					,DS_OPERADORA
					,NR_CNPJ_OPERADORA
					,DT_EMISSAO
					,CD_PRESTADOR
					,DS_PRESTADOR
					,NR_CNES_PRESTADOR)
				VALUES
					(nIdTissDemPgt
					,nIdTissMensagem
					,P_NR_REGISTRO_ANS
					,nIdTissDemPgt
					,P_DS_OPERADORA
					,P_CNPJ_OPERADORA
					,TO_CHAR(SYSDATE, 'YYYY-MM-DD')
					,nCdPrestador
					,nDsPrestador
					,nCdCnes);
				--
				--
				/********************************************************************
        *** Pagamentos por Data ou Competencia (AAAAMM) *******************
        *******************************************************************/
				nCountPgtPorData          := 0;
				nTotalInformadoPorDataDem := 0;
				nTotaLiberadoPorDataDem   := 0;
				nTotalGlosaPorDataDem     := 0;
				nTotalCreditoPorDataDem   := 0;
				nTotalDebitoPorDataDem    := 0;
				-- Obtém as datas agrupadas dos pagamentos
        --
				i := 0;


				FOR rPgtoPorData IN cPgtoPorData(P_CD_MULTI_EMPRESA, nCdPrestador, vDtCompetencia, dDtPagamento) LOOP
					--

					nCountPgtPorData       := nCountPgtPorData + 1;
					vFormaPgt              := NULL;

          --SE REDE PROPRIA - FORMATO EXCLUSIVO
          IF vTpCredenciado IN ('P') THEN
             vFormaPgt := 1;
             nCdBanco := NULL;
             vCdAgencia := NULL;
          END IF;
          --
					nTotalInformadoPorData := 0;
					nTotaLiberadoPorData   := 0;
					nTotalGlosaPorData     := 0;
					--
          /* Obtém as PKs dos itens de Pagamento ******************************/
          --REDE PROPRIA NAO ENTRA AQUI
          IF vTpCredenciado NOT IN ('P') THEN
              --

					    FOR rItensPagamento IN cItensPagamento(rPgtoPorData.DT_PAGAMENTO, nCdPrestador, P_CD_MULTI_EMPRESA) LOOP

						    --
						    -- Obtém a forma de pagamento (ver comentários na declaração do cursor)
						    OPEN cFormaPgt(rItensPagamento.CD_ITCON_PAG);
						    FETCH cFormaPgt
							    INTO vFormaPgt;
						    CLOSE cFormaPgt;
						    --
						    /*******************************************************************
                * Obtém o banco onde foi realizado o pagamento. Se foi realizado mais de
                * um pagamento em banco ficou decidido que não será informado nenhuma
                * informação, pois no TISS esse dado não é obrigatório.
                ******************************************************************/
						    nCountCdBanco := 0;
						    nCdBanco      := NULL; -- Caso o tipo de pgt não seja em banco
						    FOR rCdBanco IN cCdBanco(rItensPagamento.CD_ITCON_PAG) LOOP
							    nCountCdBanco := nCountCdBanco + 1;
							    nCdBanco      := rCdBanco.CD_BANCO;
						    END LOOP;
						    --
						    IF nCountCdBanco > 1 THEN
							    nCdBanco := NULL; -- Caso mais de um pgt em banco.
						    END IF;
						    --
						    /*******************************************************************
                * Obtém a agência onde foi realizado o pgt. Caso semelhante ao anterior
                ******************************************************************/
						    nCountCdBanco := 0;
						    vCdAgencia    := NULL; -- Caso o tipo de pgt não seja em banco
						    FOR rCdAgencia IN cCdAgencia(rItensPagamento.CD_ITCON_PAG) LOOP
							    nCountCdBanco := nCountCdBanco + 1;
							    vCdAgencia    := rCdAgencia.CD_AGENCIA;
						    END LOOP;
						    --
						    IF nCountCdBanco > 1 THEN
							    vCdAgencia := NULL; -- Caso mais de um pgt em banco.
						    END IF;
						    --
						    /*******************************************************************
                * Obtém o número da conta onde foi realizado o pgt. Caso selemelhante ao anterior
                ******************************************************************/
						    nCountCdBanco := 0;
						    vNrConta      := NULL;
						    FOR rNrConta IN cNrConta(rItensPagamento.CD_ITCON_PAG) LOOP
							    nCountCdBanco := nCountCdBanco + 1;
							    vNrConta      := rNrConta.NR_CONTA;
						    END LOOP;
						    --
						    IF nCountCdBanco > 1 THEN
							    vNrConta := NULL; -- Caso mais de um pgt em banco.
						    END IF;
						    --
						    /*******************************************************************
                * Obtém o nr do cheque. Caso selemelhante ao anterior
                ******************************************************************/
						    nCountCdBanco := 0;
						    FOR rNrCheque IN cNrCheque(rItensPagamento.CD_ITCON_PAG) LOOP
							    nCountCdBanco := nCountCdBanco + 1;
							    vNrConta      := rNrCheque.CD_CHEQUE; -- No TISS o Nr. da Conta e o Nr. do cheque são armazenados na mesma coluna
						    END LOOP;
						    --
						    IF nCountCdBanco > 1 THEN
							    vNrConta := NULL; -- Caso mais de um pgt em banco.
						    END IF;
						    --
						    /* Salva os Dados do Pagamento ************************************/
						    SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
							    INTO nIdTissDemPgtItem
							    FROM SYS.DUAL;
						    --
						    INSERT INTO DBAPS.TISS_DEM_PGT_ITEM
							    (CD_TISS_DEM_PGT_ITEM
							    ,ID_PAI
							    ,DT_PAGAMENTO
							    ,TP_FORMA_PAGAMENTO
							    ,CD_BANCO
							    ,NR_AGENCIA
							    ,NR_CONTA_CHEQUE)
						    VALUES
							    (nIdTissDemPgtItem
							    ,nIdTissDemPgt
							    ,rPgtoPorData.DT_PAGAMENTO
							    ,vFormaPgt
							    ,nCdBanco
							    ,vCdAgencia
							    ,vNrConta);
						    --
						    --
						    /******************************************************************
                * Resumo de cada pagamento
                *
                *  <element name="dataProtocolo" type="ans:st_data"/>
                *  <element name="numeroProtocolo" type="ans:st_texto12"/>
                *  <element name="numeroLote" type="ans:st_texto12"/>
                *  <element name="valorInformado" type="ans:st_decimal10-2"/>
                *  <element name="valorProcessado" type="ans:st_decimal10-2"/>
                *  <element name="valorLiberado" type="ans:st_decimal10-2"/>
                *  <element name="valorGlosa" type="ans:st_decimal10-2" minOccurs="0"/>
                *
                *****************************************************************/
						    --PRC_INSERE_DEBUG_LOG(324, 'rItensPagamento.CD_ITCON_PAG:=' ||rItensPagamento.CD_ITCON_PAG, 'MKOS');
						    --
						    --
                --buscando protocolos (relacaoProtocolos) -> ct_dadosResumoDemonstrativo
                --problema performance 02-09-20
                FOR rRepassesPorConPag IN (SELECT cd_repasse_prestador FROM dbaps.repasse_prestador WHERE cd_con_pag = rItensPagamento.cd_con_pag) LOOP
                    --
						        FOR rDadosResumoPgt IN cDadosResumoPgt(rRepassesPorConPag.CD_REPASSE_PRESTADOR, P_CD_MULTI_EMPRESA) LOOP
							        --
							        SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
								        INTO nIdTissDemPgtItemResumo
								        FROM SYS.DUAL;
							        --
							        INSERT INTO DBAPS.TISS_DEM_PGT_ITEM_RESUMO
								        (CD_TISS_DEM_PGT_ITEM_RESUMO
								        ,ID_PAI
								        ,DT_PROTOCOLO
								        ,NR_PROTOCOLO
								        ,NR_LOTE
								        ,VL_INFORMADO
								        ,VL_PROCESSADO
								        ,VL_LIBERADO
								        ,VL_GLOSA)
							        VALUES
								        (nIdTissDemPgtItemResumo
								        ,nIdTissDemPgtItem
								        ,rDadosResumoPgt.DT_PROTOCOLO
								        ,rDadosResumoPgt.NR_PROTOCOLO
								        ,rDadosResumoPgt.NR_LOTE -- LOTE PRESTADOR
								        ,rDadosResumoPgt.VL_INFORMADO
								        ,rDadosResumoPgt.VL_LIBERADO -- VL_PROCESSADO = VL_LIBERADO
								        ,rDadosResumoPgt.VL_LIBERADO
								        ,rDadosResumoPgt.VL_GLOSA);
							        nTotalInformadoPorData := nTotalInformadoPorData +
																				        nvl(rDadosResumoPgt.VL_INFORMADO, 0);
							        nTotaLiberadoPorData   := nTotaLiberadoPorData +
																				        nvl(rDadosResumoPgt.VL_LIBERADO, 0);
							        nTotalGlosaPorData     := nTotalGlosaPorData +
																				        nvl(rDadosResumoPgt.VL_GLOSA, 0);
							        --
						        END LOOP; --rDadosResumoPgt

                 END LOOP;--endloop rRepassesPorConPag
						    --
						    --
						    nTotalDebitosPorData  := 0;
						    nTotalCreditosPorData := 0;
						    -- DEBITOS CREDITOS POR DATA

						    FOR rCredDebitoPorData IN cCredDebitoPorData(rItensPagamento.CD_ITCON_PAG) LOOP
							    --
							    -- CREDITO
							    IF rCredDebitoPorData.TP_INDICADOR = 1 THEN
								    nTotalCreditosPorData := nTotalCreditosPorData +
																				    rCredDebitoPorData.VL_LANCAMENTO;
							    END IF;
							    --
							    -- DEBITO
							    IF rCredDebitoPorData.TP_INDICADOR = 2 THEN
								    nTotalDebitosPorData := nTotalDebitosPorData +
																				    rCredDebitoPorData.VL_LANCAMENTO;
							    END IF;
							    --
							    INSERT INTO DBAPS.TISS_DEM_PGT_ITEM_DEB_CRE
								    (CD_TISS_DEM_PGT_ITEM_DEB_CRE
								    ,CD_TISS_DEM_PGT_ITEM
								    ,TP_INDICADOR
								    ,TP_DEBITO_CREDITO
								    ,DS_DEBITO_CREDITO
								    ,VL_DEBITO_CREDITO)
							    VALUES
								    (DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
								    ,nIdTissDemPgtItem
								    ,rCredDebitoPorData.TP_INDICADOR
								    , -- TP_INDICADOR
								    rCredDebitoPorData.TP_DEBITO_CREDITO
								    , -- TP_DEBITO_CREDITO
								    rCredDebitoPorData.DS_OBSERVACAO
								    , -- DS_DB_CR
								    rCredDebitoPorData.VL_LANCAMENTO -- VL_DB_CR
								    );
							    --
							    aCredDeb(i).TP_INDICADOR := rCredDebitoPorData.TP_INDICADOR;
							    aCredDeb(i).TP_DEBITO_CREDITO := rCredDebitoPorData.TP_DEBITO_CREDITO;
							    aCredDeb(i).DS_OBSERVACAO := rCredDebitoPorData.DS_OBSERVACAO;
							    aCredDeb(i).VL_LANCAMENTO := rCredDebitoPorData.VL_LANCAMENTO;
							    --
							    i := i + 1;
							    --
						    --
						    END LOOP; --FOR rCredDebitoPorData IN cCredDebitoPorData(rItensPagamento.CD_ITCON_PAG) LOOP
						    --
						    --
						    /*********************************************************************
                * Totais Brutos por Data + totaisLiquidos por data
                * Obs: valor liquido é igual ao liberado pois o nosso repasse já considera os creditos/debitos
                * Atualmente não existe uma estrutura de consolidação do repasse para
                * retornar os dados com mais precisão.
                *******************************************************************/
						    --
						    UPDATE DBAPS.TISS_DEM_PGT_ITEM
							    SET vl_total_info_item       = nTotalInformadoPorData
									    ,vl_total_processado_item = nTotaLiberadoPorData
									    ,vl_total_liberado_item   = nTotaLiberadoPorData
									    ,vl_total_glosa_item      = nTotalGlosaPorData
									    ,vl_total_debitos_item    = nTotalDebitosPorData
									    ,vl_total_creditos_item   = nTotalCreditosPorData
									    ,vl_liquido_item          = nTotaLiberadoPorData
						    WHERE CD_TISS_DEM_PGT_ITEM = nIdTissDemPgtItem;
						    --
						    -- total geral bruto (variaveis terminadas em DEM devido nome das colunas no banco)
						    nTotalInformadoPorDataDem := nTotalInformadoPorDataDem +
																				    NVL(nTotalInformadoPorData, 0);
						    nTotaLiberadoPorDataDem   := nTotaLiberadoPorDataDem +
																				    NVL(nTotaLiberadoPorData, 0);
						    nTotalGlosaPorDataDem     := nTotalGlosaPorDataDem +
																				    NVL(nTotalGlosaPorData, 0);
						    -- total geral liquido
						    nTotalDebitoPorDataDem  := nTotalDebitoPorDataDem +
																			    nTotalDebitosPorData;
						    nTotalCreditoPorDataDem := nTotalCreditoPorDataDem +
																			    nTotalCreditosPorData;
						    --
					    /* Débitos/Créditos *************************************************/
					    --TODO
					    END LOOP; -- FOR rItensPagamento IN cItensPagamento(rPgtoPorData.DT_PAGAMENTO
              --
          END IF; --ENDIF vTpCredenciado NOT IN ('P')
				--
				--
				END LOOP; -- FOR rPgtoPorData IN cPgtoPorData(P_CD_MULTI_EMPRESA,
				--
				-- registro ficticio - condição de break
				aCredDeb(i).TP_INDICADOR := -1;
				IF nCountPgtPorData = 0 THEN
					--
					/* Se não existe dados no extrato, gera mensagem de erro */
					INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
						(CD_TISS_DEM_RETORNO_ERRO
						,CD_TISS_MENSAGEM
						,CD_MOTIVO_GLOSA
						,DS_MOTIVO_GLOSA)
					VALUES
						(nIdTissDemPgt
						,nIdTissMensagem
						,'5013'
						,'NÃO FORAM ENCONTRADOS PAGAMENTOS NA ' ||
						 DECODE(rSolicitacao.DT_COMPETENCIA, NULL, 'DATA DE PAGAMENTO', 'COMPETÊNCIA') ||
						 ' FORNECIDA: ' ||
						 NVL(rSolicitacao.DT_COMPETENCIA, TO_CHAR(rSolicitacao.DT_PAGAMENTO, 'DD/MM/YYYY')));
					--
					--
				ELSE
					--IF nCountPgtPorData = 0 THEN
					--
					/* Totais Brutos Demonstrativos *************************************/
					UPDATE DBAPS.TISS_DEM_PGT
						 SET VL_TOTAL_GERAL_INFORMADO  = nTotalInformadoPorDataDem
								,VL_TOTAL_GERAL_PROCESSADO = nTotalInformadoPorDataDem
								,VL_TOTAL_GERAL_LIBERADO   = nTotaLiberadoPorDataDem
								,VL_TOTAL_GERAL_GLOSA      = nTotalGlosaPorDataDem
								,VL_TOTAL_DEBITOS_DEM      = nTotalDebitoPorDataDem
								,VL_TOTAL_CREDITOS_DEM     = nTotalCreditoPorDataDem
								,VL_LIBERADO_DEM           = nTotaLiberadoPorDataDem
                ,VL_INFO_BRUTO             = nTotalInformadoPorDataDem
								,VL_PROCESSADO_BRUTO       = nTotalInformadoPorDataDem
								,VL_LIBERADO_BRUTO         = nTotaLiberadoPorDataDem
								,VL_GLOSA_BRUTO            = nTotalGlosaPorDataDem
					 WHERE ID = nIdTissDemPgt;
					--
					--
					/* debitos/Creditos do Demonstrativo - exibir todos */
					i := 0;
					WHILE (Nvl(aCredDeb(i).TP_INDICADOR, 0) <> -1) LOOP
						--
						INSERT INTO DBAPS.TISS_DEM_PGT_DEB_CRE
							(CD_TISS_DEM_PGT_DEB_CRE
							,ID_PAI
							,TP_INDICADOR
							,TP_DEBITO_CREDITO
							,DS_DB_CR
							,VL_DB_CR)
						VALUES
							(DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
							,nIdTissDemPgt
							,aCredDeb(i).TP_INDICADOR
							, -- TP_INDICADOR
							 aCredDeb(i).TP_DEBITO_CREDITO
							, -- TP_DEBITO_CREDITO
							 aCredDeb(i).DS_OBSERVACAO
							, -- DS_DB_CR
							 aCredDeb(i).VL_LANCAMENTO -- VL_DB_CR
							 );
						--
						i := i + 1;
						--
					--
					END LOOP; -- WHILE (Nvl(aCredDeb(i).TP_INDICADOR, 0) <> -1) LOOP
					--
					--
					/* totaisLiquidosDemonstrativo TODO */
				END IF; -- IF nCountPgtPorData = 0 THEN
				--
				--
			END IF; -- IF vCdGlosa IS NOT NULL THEN
			--
		END IF; --  IF P_CD_GLOSA_CABECALHO IS NOT NULL THEN
		--
		--
		RETURN nIdTissMensagem;
	END;
	/*****************************************************************************
  * Grava uma resposta de erro para o DEMONSTRATIVO de RETORNO
  ****************************************************************************/
	FUNCTION gravarRespostaErro(P_ID_TISS_MENSAGEM       IN NUMBER
														 ,P_NR_REGISTRO_ANS        IN VARCHAR2
														 ,P_NR_CNPJ_OPERADORA      IN VARCHAR2
														 ,P_DS_OPERADORA           IN VARCHAR2
														 ,P_CD_VERSAO              IN VARCHAR2
														 ,P_CD_PRESTADOR_OPERADORA IN NUMBER
														 ,P_NR_CNPJ_PRESTADOR      IN VARCHAR2
														 ,P_NR_CPF_PRESTADOR       IN VARCHAR2
														 ,P_CD_GLOSA               IN VARCHAR2
														 ,P_DS_GLOSA               IN VARCHAR2
														 ,P_CD_MULTI_EMPRESA       IN NUMBER)
		RETURN NUMBER IS
	BEGIN
		-- BUSCANDO SEQUENCE
		SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
			INTO nIdTissDemErro
			FROM DUAL;
		nIdTissMensagem := dbaps.FNC_TISS_INSERE_CABECALHO(P_ID_TISS_MENSAGEM
                                                      , 'DEMONSTRATIVO_PAGAMENTO' -- Teve que se escolher entre pagamento ou analise de conta
																											, 'demonstrativoPagamento'
                                                      , P_NR_REGISTRO_ANS
                                                      , P_NR_CNPJ_OPERADORA
                                                      , P_CD_VERSAO
                                                      , P_CD_PRESTADOR_OPERADORA
                                                      , P_NR_CNPJ_PRESTADOR
                                                      , P_NR_CPF_PRESTADOR
                                                      , P_CD_GLOSA
                                                      , P_DS_GLOSA
                                                      , P_DS_GLOSA);
		/**
    * CABECALHO DA MENSAGEM COM GLOSA
    */
		INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
			(CD_TISS_DEM_RETORNO_ERRO
			,CD_TISS_MENSAGEM
			,CD_MOTIVO_GLOSA
			,DS_MOTIVO_GLOSA)
		VALUES
			(nIdTissDemErro
			,nIdTissMensagem
			,P_CD_GLOSA
			,P_DS_GLOSA);
		RETURN nIdTissMensagem;
	END; --END - gravarRespostaErro
	/******************************************************************************
  ************************** BLOCO PRINCIPAL ***********************************
  ******************************************************************************/
BEGIN
	-- Busca os dados da Mensagem
	OPEN cTissMensagem;
	FETCH cTissMensagem
		INTO rTissMensagem;
	CLOSE cTissMensagem;
	/* Valida cabecalho da mensagem TISS ****************************************/
	dbaps.prc_tiss_valida_cabecalho(P_ID_TISS_MENSAGEM, nCdPrestadorNaOperadora, -- retorno
																	nNrRegistroAnsOrigem, -- retorno
																	nCdMultiEmpresaOrigem, -- retorno
																	nCnpjOperadora, -- retorno
																	vDsOperadora, -- retorno
																	vCdGlosa, -- retorno
																	vDsGlosa); -- retorno
	/*
  * Se não retornou código do prestador na operadora
  * busca os dados da mensagem original
  */
	IF nCdPrestadorNaOperadora IS NULL THEN
		nCdPrestadorNaOperadora := rTissMensagem.CD_PRESTADOR_OPERADORA;
		nNrCnpjPrestador        := rTissMensagem.NR_CNPJ_PRESTADOR_OPERADORA;
		nNrCpfPrestador         := rTissMensagem.NR_CPF_PRESTADOR_OPERADORA;
	END IF;
	/* Se não houve glosa - atribui a multiempresa */
	IF vCdGlosa IS NULL THEN
		DBAMV.PKG_MV2000.ATRIBUI_EMPRESA(nCdMultiEmpresaOrigem);
		OPEN cWebserviceAtivo(nCdMultiEmpresaOrigem);
		FETCH cWebserviceAtivo
			INTO rWebserviceAtivo;
		CLOSE cWebserviceAtivo;
		/* Valida se WebService está ativo **************************************/
		IF upper(nvl(rWebserviceAtivo.VALOR, 'N')) = 'N' THEN
			vCdGlosa := '5013';
			vDsGlosa := 'WEB SERVICE DEMONSTRATIVO RETORNO NÃO ESTÁ ATIVO - ENTRE EM CONTATO COM A OPERADORA';
		END IF;
	END IF;
	IF vCdGlosa IS NULL
		 AND rTissMensagem.TP_DEMONSTRATIVO IS NULL THEN
		vCdGlosa := '5013';
		vDsGlosa := 'NÃO FOI INFORMADO UM TIPO DE DEMONSTRATIVO NA SOLICITAÇÃO';
	END IF;
	IF rTissMensagem.TP_DEMONSTRATIVO = '1' THEN
		-- DEMONSTRATIVA DE PAGAMENTO
		P_ID_TISS_MENSAGEM_OUT := gravarRespostaDemPagamento(rTissMensagem.ID_DEM_RETORNO, P_ID_TISS_MENSAGEM, Nvl(nNrRegistroAnsOrigem, nvl(rTissMensagem.NR_REGISTRO_ANS_DESTINO, 999999)), nCnpjOperadora, vDsOperadora, rTissMensagem.CD_VERSAO, nCdPrestadorNaOperadora, nNrCnpjPrestador, nNrCpfPrestador, vCdGlosa, vDsGlosa, nCdMultiEmpresaOrigem);
	ELSIF rTissMensagem.TP_DEMONSTRATIVO IN ('2', '3') THEN
  		-- DEMONSTRATIVA DE ANALISE
		P_ID_TISS_MENSAGEM_OUT := gravarRespostaDemAnalise(rTissMensagem.ID_DEM_RETORNO, P_ID_TISS_MENSAGEM, Nvl(nNrRegistroAnsOrigem, nvl(rTissMensagem.NR_REGISTRO_ANS_DESTINO, 999999)), nCnpjOperadora, vDsOperadora, rTissMensagem.CD_VERSAO, nCdPrestadorNaOperadora, nNrCnpjPrestador, nNrCpfPrestador, vCdGlosa, vDsGlosa, nCdMultiEmpresaOrigem);
	/*ELSIF rTissMensagem.TP_DEMONSTRATIVO = '3' THEN
		P_ID_TISS_MENSAGEM_OUT := gravarRespostaErro(P_ID_TISS_MENSAGEM, Nvl(nNrRegistroAnsOrigem, nvl(rTissMensagem.NR_REGISTRO_ANS_DESTINO, 999999)), nCnpjOperadora, vDsOperadora, rTissMensagem.CD_VERSAO, nCdPrestadorNaOperadora, nNrCnpjPrestador, nNrCpfPrestador, '5013', 'DEMONSTRATIVO DE PAGAMENTO - ODONTOLOGIA NÃO ATIVO NO MOMENTO', nCdMultiEmpresaOrigem);*/
	ELSE
		P_ID_TISS_MENSAGEM_OUT := gravarRespostaErro(P_ID_TISS_MENSAGEM, Nvl(nNrRegistroAnsOrigem, nvl(rTissMensagem.NR_REGISTRO_ANS_DESTINO, 999999)), nCnpjOperadora, vDsOperadora, rTissMensagem.CD_VERSAO, nCdPrestadorNaOperadora, nNrCnpjPrestador, nNrCpfPrestador, vCdGlosa, vDsGlosa, nCdMultiEmpresaOrigem);
	END IF;
EXCEPTION
	WHEN OTHERS THEN
		vExcecao      := SQLERRM;
		vExcecaoLinha := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
		SELECT DBAPS.SEQ_TISS_MENSAGEM.NEXTVAL
			INTO nIdTissDemAna
			FROM SYS.DUAL;
		SELECT DBAPS.SEQ_TISS_MENSAGEM_LOG.NEXTVAL
			INTO nIdTissMensagemLog
			FROM DUAL;
		-- INSERINDO NO LOG DE ERROS
		INSERT INTO DBAPS.TISS_MENSAGEM_LOG
			(CD_TISS_MENSAGEM_LOG
			,CD_TISS_MENSAGEM
			,DT_LOG
			,DS_LOG)
		VALUES
			(nIdTissMensagemLog
			,P_ID_TISS_MENSAGEM
			,SYSDATE
			,'ERRO: ' || vExcecao || ' LINHA DO ERRO: ' || vExcecaoLinha);
		-- BUSCANDO VERSAO ATUAL DO TISS - VALORES IGUAIS PARA QUALQUER MULTIEMPRESA
		SELECT valor
			INTO vVersaoTiss
			FROM DBAPS.MVS_CONFIGURACAO
		 WHERE CHAVE = 'VERSAO_TISS'
			 AND CD_MULTI_EMPRESA = DBAMV.PKG_MV2000.LE_EMPRESA
			 AND ROWNUM = 1;
		-- Grava o cabecalho da resposta
		P_ID_TISS_MENSAGEM_OUT := dbaps.FNC_TISS_INSERE_CABECALHO(P_ID_TISS_MENSAGEM, vTpTransacao, vNmXML, '999999', NULL, vVersaoTiss, 999999, NULL, NULL, '5013', 'OCORREU UM ERRO NO PROCESSAMENTO DA SUA REQUISIÇÃO. ERRO CÓD: ' ||
																															 nIdTissMensagemLog, 'OCORREU UM ERRO NO PROCESSAMENTO DA SUA REQUISIÇÃO. ERRO CÓD: ' ||
																															 nIdTissMensagemLog);
		INSERT INTO DBAPS.TISS_DEM_RETORNO_ERRO
			(CD_TISS_DEM_RETORNO_ERRO
			,CD_TISS_MENSAGEM
			,CD_MOTIVO_GLOSA
			,DS_MOTIVO_GLOSA)
		VALUES
			(nIdTissDemAna
			,P_ID_TISS_MENSAGEM_OUT
			,'5013'
			,'OCORREU UM ERRO NO PROCESSAMENTO DA SUA REQUISIÇÃO. ERRO CÓD: ' ||
			 nIdTissMensagemLog);
END;
/

GRANT EXECUTE ON dbaps.prc_tiss_demonstrativos TO dbamv;
GRANT EXECUTE ON dbaps.prc_tiss_demonstrativos TO dbasgu;
GRANT EXECUTE ON dbaps.prc_tiss_demonstrativos TO mv2000;
GRANT EXECUTE ON dbaps.prc_tiss_demonstrativos TO mvintegra;
