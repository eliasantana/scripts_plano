PROMPT CREATE OR REPLACE PROCEDURE dbaps.prc_ident_ctactb_custos
CREATE OR REPLACE PROCEDURE dbaps.prc_ident_ctactb_custos

( PNR_MESANO_INICIAL IN VARCHAR2
 ,PNR_MESANO_FINAL IN VARCHAR2
 ,PSN_DESPESA IN VARCHAR2
 ,PSN_RECEITA IN VARCHAR2
 ,PSN_CUSTO IN VARCHAR2
 ,PCD_MENS_CONTRATO IN NUMBER DEFAULT NULL
 ,PCD_FATURA IN NUMBER DEFAULT NULL
 ,PCD_PRESTADOR IN NUMBER DEFAULT NULL
 ,PCD_REEMBOLSO IN NUMBER DEFAULT NULL)

IS

    /**************************************************************
    <objeto>
     <nome>prc_ident_ctactb_custos</nome>
     <usuario>Paulo Gustavo</usuario>
     <alteracao>05/03/2020 11:20</alteracao>
     <descricao>Classificar a conta de coparticipação na despesa, independente da operadora. So estava permitindo em Unimeds</descricao>
     <funcionalidade>Aplicar a classificação contábil das receitas e despesas</funcionalidade>
     <parametro>
       PNR_MESANO_INICIAL - Competência inicial no formato YYYYMM
       PNR_MESANO_FINAL - Competência final no formato YYYYMM
       PSN_DESPESA - Indica se será aplicada a classificação da despesa
       PSN_RECEITA - Indica se será aplicada a classificação da receita
       PSN_CUSTO - Indica se será aplicada a precificação de custos
       PCD_MENS_CONTRATO - Indica se serão classificadas apenas as receitas dessa mensalidade
       PCD_FATURA - Indica se serão classificadas apenas as despesas dessa fatura
       PCD_PRESTADOR - Indica se serão classificadas apenas as despesas desse prestador
       PCD_REEMBOLSO - Indica se serão classificadas apenas as despesas desse reembolso
  	 </parametro>
     <tags>Contabilidade, Apropriação, Classificação, Fechamento contábil</tags>
     <versao>1.31</versao>
    </objeto>
   **************************************************************/

CURSOR cLctoRecebimento ( PCD_MENS_CON IN NUMBER ) IS
  SELECT MC.CD_MENS_CONTRATO
    FROM DBAPS.MENS_CONTRATO MC
    WHERE MC.CD_MENS_CONTRATO = PCD_MENS_CON
      AND EXISTS ( SELECT 1
                     FROM DBAPS.MENS_CONTRATO_REC MCR, DBAPS.MEN_CON_REC_LCTO MCRL
                     WHERE MCR.CD_MENS_CONTRATO = MC.CD_MENS_CONTRATO
                       AND MCR.CD_MENS_CONTRATO_REC = MCRL.CD_MENS_CONTRATO_REC );

CURSOR cGlosaFaturamento IS
  SELECT A550.NR_DOC_1_A500 CD_MENS_CONTRATO,
         A550.DT_GERACAO,
         VCMF.CD_PRESTADOR,
         VCMF.TP_CONTA,
         VCMF.CD_CONTA_MEDICA,
         VCMF.CD_LANCAMENTO,
         VCMF.CD_PROCEDIMENTO,
         Decode( VCMF.TP_CONTA, 'A', 'N', 'S' ) TP_GUIA,
         MC.CD_CONTRATO,
         VCMF.CD_MATRICULA,
         Nvl( US.CD_PLANO, Nvl( CT.CD_PLANO, -1 ) ) CD_PLANO,
         CASE
           WHEN MC.VL_MENSALIDADE < Nvl( MC.VL_PAGO, 0 ) AND MC.TP_QUITACAO <> 'A' THEN
             'S'
           ELSE
             'N'
         END SN_RECEBIMENTO_PARCIAL
    FROM DBAPS.PTU_A550_R551 A550,
        DBAPS.V_CTAS_MEDICAS_FATURA VCMF,
        DBAPS.MENS_CONTRATO MC,
        DBAPS.CONTRATO CT,
        DBAPS.USUARIO US,
        DBAPS.PTU_REMESSA_RETORNO PTU_RR
    WHERE A550.DT_GERACAO >= TO_DATE(PNR_MESANO_INICIAL, 'YYYYMM' )
      AND A550.DT_GERACAO <= Last_Day(TO_DATE(PNR_MESANO_FINAL, 'YYYYMM' ))
      AND A550.CD_MULTI_EMPRESA=DBAMV.PKG_MV2000.LE_EMPRESA
      AND A550.NR_DOC_1_A500 = To_Char(VCMF.CD_MENS_CONTRATO)
      AND A550.NR_DOC_1_A500 = MC.CD_MENS_CONTRATO
      AND A550.CD_PTU_REMESSA_RETORNO = PTU_RR.CD_PTU_REMESSA_RETORNO
      AND A550.TP_ARQUIVO = 1
      AND PTU_RR.TP_PROCESSO = 'RET'
      AND PTU_RR.TP_ARQUIVO = 'A550'
      AND MC.CD_CONTRATO = CT.CD_CONTRATO
      AND VCMF.CD_MATRICULA = US.CD_MATRICULA(+)
      AND ( ( Nvl( VCMF.VL_UNIT_CONTESTADO, 0 ) * Nvl( VCMF.QT_CONTESTADO, 0 ) ) + Nvl( VCMF.VL_UNIT_TAXA_ACORDADO, 0 ) ) <> 0;

CURSOR cDevolucao ( PCD_MULTI_EMPRESA IN NUMBER ) IS
  SELECT cd_matricula,
         cd_plano,
         nm_segurado,
         cd_contrato,
         cd_reembolso,
         vl_cobrado,
         cd_lcto_mensalidade,
         cd_procedimento,
         cd_mens_contrato,
         To_Date(nr_ano||nr_mes, 'yyyymm') dt_vigencia,
         dt_inclusao,
         dt_cancelamento,
         tp_lancamento,
         nr_mes,
         nr_ano
  FROM
  (
  SELECT r.cd_matricula,
         u.cd_plano,
         u.nm_segurado,
         u.cd_contrato,
         ir.cd_reembolso,
         ir.vl_cobrado,
         ir.cd_lcto_mensalidade,
         ir.cd_procedimento,
         r.cd_mens_contrato,
         r.dt_contabilizacao dt_inclusao,
         r.dt_cancelamento,
         'FTA' tp_lancamento,
         Nvl( mc.nr_mes, r.nr_mes ) nr_mes,
         Nvl( mc.nr_ano, r.nr_ano ) nr_ano
    FROM dbaps.reembolso r, dbaps.itreembolso ir, dbaps.usuario u, dbaps.mens_contrato mc
    WHERE r.tp_reembolso = 'D'
      AND r.cd_reembolso = ir.cd_reembolso
      AND r.cd_matricula = u.cd_matricula
      AND r.cd_mens_contrato = mc.cd_mens_contrato(+)
      AND r.cd_multi_empresa = PCD_MULTI_EMPRESA
      AND ( r.dt_cancelamento IS NULL OR To_Date( Nvl( mc.nr_ano, r.nr_ano ) || Nvl( mc.nr_mes, r.nr_mes ), 'yyyymm' ) < Trunc( r.dt_cancelamento, 'mm' ) )
      AND Nvl( mc.nr_ano, r.nr_ano ) || Nvl( mc.nr_mes, r.nr_mes ) BETWEEN PNR_MESANO_INICIAL AND PNR_MESANO_FINAL

  UNION ALL

  SELECT r.cd_matricula,
         u.cd_plano,
         u.nm_segurado,
         u.cd_contrato,
         ir.cd_reembolso,
         ir.vl_cobrado,
         ir.cd_lcto_mensalidade,
         ir.cd_procedimento,
         r.cd_mens_contrato,
         r.dt_contabilizacao dt_inclusao,
         r.dt_cancelamento,
         'CAN' tp_lancamento,
         Nvl( mc.nr_mes, r.nr_mes ) nr_mes,
         Nvl( mc.nr_ano, r.nr_ano ) nr_ano
    FROM dbaps.reembolso r, dbaps.itreembolso ir, dbaps.usuario u, dbaps.mens_contrato mc
    WHERE r.tp_reembolso = 'D'
      AND r.cd_reembolso = ir.cd_reembolso
      AND r.cd_matricula = u.cd_matricula
      AND r.cd_mens_contrato = mc.cd_mens_contrato(+)
      AND r.cd_multi_empresa = PCD_MULTI_EMPRESA
      AND r.dt_cancelamento IS NOT NULL
      AND r.dt_cancelamento > To_Date( Nvl( mc.nr_ano, r.nr_ano ) || Nvl( mc.nr_mes, r.nr_mes ), 'yyyymm' )
      AND To_Char(r.dt_cancelamento, 'yyyymm' ) BETWEEN PNR_MESANO_INICIAL AND PNR_MESANO_FINAL
   ) dev;

CURSOR cMensContrato ( PCD_MULTI_EMPRESA IN NUMBER ) IS
  SELECT DISTINCT CD_MENS_CONTRATO, TP_CONTRATO, TP_RECEITA, CD_CONTRATO
    FROM
    (
      SELECT MC.CD_MENS_CONTRATO, CT.TP_CONTRATO, MC.TP_RECEITA, MC.CD_CONTRATO
        FROM DBAPS.MENS_CONTRATO MC, DBAPS.CONTRATO CT
        WHERE MC.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
          AND MC.CD_CONTRATO = CT.CD_CONTRATO
          AND MC.DT_EMISSAO >= To_Date( PNR_MESANO_INICIAL, 'YYYYMM' )
          AND MC.DT_EMISSAO <= Last_Day( To_Date( PNR_MESANO_FINAL, 'YYYYMM' ) )
          AND NOT EXISTS  ( SELECT 1
                              FROM DBAPS.MOTIVOS_CANCELAMENTO MOT_CANC
                              WHERE MOT_CANC.CD_MOTIVO_CANCELAMENTO = MC.CD_MOTIVO_CANCELAMENTO
                                AND MOT_CANC.TP_CANCELAMENTO = 'A' )
      UNION ALL
      SELECT MC.CD_MENS_CONTRATO, CT.TP_CONTRATO, MC.TP_RECEITA, MC.CD_CONTRATO
        FROM DBAPS.MENS_CONTRATO MC, DBAPS.CONTRATO CT
        WHERE MC.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
          AND MC.CD_CONTRATO = CT.CD_CONTRATO
          AND MC.DT_CONTABILIZACAO >= To_Date( PNR_MESANO_INICIAL, 'YYYYMM' )
          AND MC.DT_CONTABILIZACAO <= Last_Day( To_Date( PNR_MESANO_FINAL, 'YYYYMM' ) )
          AND NOT EXISTS  ( SELECT 1
                              FROM DBAPS.MOTIVOS_CANCELAMENTO MOT_CANC
                              WHERE MOT_CANC.CD_MOTIVO_CANCELAMENTO = MC.CD_MOTIVO_CANCELAMENTO
                                AND MOT_CANC.TP_CANCELAMENTO = 'A' )
      UNION ALL

      SELECT MC.CD_MENS_CONTRATO, CT.TP_CONTRATO, MC.TP_RECEITA, MC.CD_CONTRATO
        FROM DBAPS.MENS_CONTRATO MC, DBAPS.CONTRATO CT
        WHERE MC.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
          AND MC.CD_CONTRATO = CT.CD_CONTRATO
          AND MC.DT_CANCELAMENTO >= To_Date( PNR_MESANO_INICIAL, 'YYYYMM' )
          AND MC.DT_CANCELAMENTO <= Last_Day( To_Date( PNR_MESANO_FINAL, 'YYYYMM' ) )
          AND NOT EXISTS  ( SELECT 1
                              FROM DBAPS.MOTIVOS_CANCELAMENTO MOT_CANC
                              WHERE MOT_CANC.CD_MOTIVO_CANCELAMENTO = MC.CD_MOTIVO_CANCELAMENTO
                                AND MOT_CANC.TP_CANCELAMENTO = 'A' )

      UNION ALL

      SELECT MCR.CD_MENS_CONTRATO, CT.TP_CONTRATO, MC.TP_RECEITA, MC.CD_CONTRATO
        FROM DBAPS.MENS_CONTRATO_REC MCR, DBAPS.MENS_CONTRATO MC, DBAPS.CONTRATO CT
        WHERE MCR.DT_CREDITO >= To_Date( PNR_MESANO_INICIAL, 'YYYYMM' )
          AND MCR.DT_CREDITO <= Last_Day( To_Date( PNR_MESANO_FINAL, 'YYYYMM' ) )
          AND MCR.CD_MENS_CONTRATO = MC.CD_MENS_CONTRATO
          AND MC.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
          AND MC.CD_CONTRATO = CT.CD_CONTRATO

    ) lst /*WHERE cd_mens_contrato IN ( 171054, 164967)*/;


CURSOR cReceitas ( PCD_MULTI_EMPRESA IN NUMBER, PCD_MENS_CONTRATO IN NUMBER ) IS
  SELECT DISTINCT
        CD_MENS_CONTRATO
        ,CD_LCTO_MENSALIDADE
        ,DT_CANCELAMENTO
        ,DT_VIGENCIA
        ,NR_ANO
        ,NR_MES
        ,CD_PLANO
        ,DT_FINAL_MENSALIDADE
        ,SN_PRORATA
        ,CD_CONTRATO
        ,DT_INICIO_COBERTURA
        ,SN_SEGREGACAO_ATO
    FROM
    (
    SELECT MC.CD_MENS_CONTRATO
          ,IMC.CD_LCTO_MENSALIDADE CD_LCTO_MENSALIDADE
          ,MC.DT_CANCELAMENTO
          ,MC.DT_CONTABILIZACAO DT_VIGENCIA
          ,MC.NR_ANO
          ,MC.NR_MES
          ,CT.CD_PLANO CD_PLANO
          ,MC.DT_FINAL_MENSALIDADE
          ,LM.SN_PRORATA SN_PRORATA
          ,MC.CD_CONTRATO
          ,MC.DT_INICIO_COBERTURA
          ,LM.SN_SEGREGACAO_ATO
          ,CT.TP_CONTRATO
          ,MC.TP_RECEITA
      FROM DBAPS.MENS_CONTRATO MC
          ,DBAPS.CONTRATO CT
          ,DBAPS.ITMENS_CONTRATO IMC
          ,DBAPS.LCTO_MENSALIDADE LM
      WHERE MC.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
        AND MC.CD_MENS_CONTRATO = PCD_MENS_CONTRATO
        AND MC.CD_MENS_CONTRATO = IMC.CD_MENS_CONTRATO
        AND MC.CD_CONTRATO = CT.CD_CONTRATO
--        AND CT.TP_CONTRATO <> 'U'
        AND ( MC.TP_RECEITA <> 'F' OR ( MC.TP_RECEITA = 'F' AND Nvl( IMC.SN_LCTO_RECEBIMENTO, 'N' ) = 'S' ) )
        AND IMC.CD_LCTO_MENSALIDADE = LM.CD_LCTO_MENSALIDADE
        AND CT.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
        AND NOT EXISTS ( SELECT 1
                          FROM DBAPS.MENS_USUARIO MU
                              ,DBAPS.ITMENS_USUARIO IMU
                          WHERE MU.CD_MENS_CONTRATO = MC.CD_MENS_CONTRATO
                            AND MU.CD_MENS_CONTRATO = PCD_MENS_CONTRATO
                            AND MU.CD_MENS_USUARIO = IMU.CD_MENS_USUARIO
--                            AND MU.CD_CONTRATO = MC.CD_CONTRATO
                            AND IMU.CD_LCTO_MENSALIDADE = IMC.CD_LCTO_MENSALIDADE )

    UNION ALL

    SELECT MC.CD_MENS_CONTRATO
          ,IM.CD_LCTO_MENSALIDADE CD_LCTO_MENSALIDADE
          ,MC.DT_CANCELAMENTO
          ,MC.DT_CONTABILIZACAO DT_VIGENCIA
          ,MC.NR_ANO
          ,MC.NR_MES
          ,MU.CD_PLANO CD_PLANO
          ,MC.DT_FINAL_MENSALIDADE
          ,LM.SN_PRORATA SN_PRORATA
          ,MC.CD_CONTRATO
          ,MC.DT_INICIO_COBERTURA
          ,LM.SN_SEGREGACAO_ATO
          ,CT.TP_CONTRATO
          ,MC.TP_RECEITA
      FROM DBAPS.MENS_CONTRATO MC
          ,DBAPS.CONTRATO CT
          ,DBAPS.MENS_USUARIO MU
          ,DBAPS.ITMENS_USUARIO IM
          ,DBAPS.LCTO_MENSALIDADE LM
      WHERE MC.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
        AND MC.CD_MENS_CONTRATO = PCD_MENS_CONTRATO
        AND MC.CD_MENS_CONTRATO = MU.CD_MENS_CONTRATO
        AND MC.CD_CONTRATO = CT.CD_CONTRATO
--        AND CT.TP_CONTRATO <> 'U'
        AND MC.TP_RECEITA <> 'F'
        AND MU.CD_MENS_USUARIO = IM.CD_MENS_USUARIO
--        AND MU.CD_CONTRATO = CT.CD_CONTRATO
        AND IM.CD_LCTO_MENSALIDADE = LM.CD_LCTO_MENSALIDADE
        AND CT.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
    );

CURSOR cItGuia ( PCD_MENS_CONTRATO IN NUMBER) IS
	SELECT cd_prestador_executor,
        tp_guia,
        cd_procedimento,
        nr_guia,
        cd_itguia,
        cd_itguia_ctactb,
        tp_origem,
        cd_conta_medica,
        cd_lancamento,
        tp_conta
  FROM dbaps.v_guia_franquia
  WHERE cd_mens_contrato = PCD_MENS_CONTRATO;

CURSOR cGrupoFranquia IS
  SELECT LM.CD_LCTO_MENSALIDADE
    FROM DBAPS.PLANO_DE_SAUDE PS,
          DBAPS.LCTO_MENSALIDADE LM
    WHERE PS.CD_GRUPO_FRANQUIA = LM.CD_LCTO_MENSALIDADE;

CURSOR cPlanoLctoMens (PCD_PLANO IN NUMBER, PCD_LCTO_MENSALIDADE IN NUMBER) IS
  SELECT 'N' SN_CONTABILIZA_FRANQUIA
    FROM DBAPS.PLANO_LCTO_MENSALIDADE
    WHERE CD_PLANO = PCD_PLANO
      AND CD_LCTO_MENSALIDADE = PCD_LCTO_MENSALIDADE;

nCdGrupoFaanquia NUMBER;
cSnContabilizaFranquia VARCHAR2(1);

nCdReduzido DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzido2 DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzido3 DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzido4 DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzido5 DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzido6 DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;

nCdReduzidoAtoPrincipal DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzidoAtoAuxiliar DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;
nCdReduzidoAtoNaoCoop DBAMV.PLANO_CONTAS.CD_REDUZIDO%TYPE;

nCdSetor DBAMV.SETOR.CD_SETOR%TYPE;
nCdItemRes DBAMV.ITEM_RES.CD_ITEM_RES%TYPE;
nCdMatricula DBAPS.USUARIO.CD_MATRICULA%TYPE;
nCdPlano DBAPS.PLANO.CD_PLANO%TYPE;
nVlCusto NUMBER;
cSnInternacao VARCHAR2(1);
cTpContaContabil VARCHAR2(1);
cCdSetor VARCHAR2(2000);
cCdItemRes VARCHAR2(2000);
nCdGrupoFranquia NUMBER(2,0);
cSnContabiliza VARCHAR2(2000);
nCdMensContrato NUMBER;
cExisteLctoRecebimento VARCHAR2(1);
dDtInicioCobertura DATE;
dadosProc procedimento_type;
cCdProcedimento DBAPS.PROCEDIMENTO.CD_PROCEDIMENTO%TYPE;
cDsProcedimento DBAPS.PROCEDIMENTO.DS_PROCEDIMENTO%TYPE;
nCdGrupoProcedimento NUMBER;
nCdPorteAnestesico NUMBER;
nTpFilme NUMBER;
cSnPrestador VARCHAR2(1);

nCont NUMBER := 0;
ncont2 number := 0;

cTpProvisaoReceita VARCHAR2(100);
cTpContabilizacao VARCHAR2(100);

nVlTotalCusto NUMBER;
nVlTotalRedePropria NUMBER;
nVlFatorCusto NUMBER;
nQtdCobrado NUMBER;

CURSOR cPercAto IS
  SELECT VL_PERC_ATO_PRINCIPAL, VL_PERC_ATO_AUXILIAR, VL_PERC_ATO_NAO_COOPERATIVO
    FROM DBAPS.CONSOLIDA_PERCENTUAL_ATO
    WHERE CD_MULTI_EMPRESA = DBAMV.PKG_MV2000.LE_EMPRESA
      AND DT_COMPETENCIA = Trunc( To_Date(PNR_MESANO_INICIAL, 'YYYYMM'), 'MM');

nVlPercAP NUMBER;
nVlPercAA NUMBER;
nVlPercNC NUMBER;

nCdTaxaAdmUnimed NUMBER;
nCdReduzidoReceitaTxAdm NUMBER;
nCdReduzidoAtivoTxAdm NUMBER;
nCdReduzidoCancTxAdm NUMBER;
nCdReduzidoFATxAdm NUMBER;
nCdReduzidoACP NUMBER;
nCdReduzidoACA NUMBER;
nCdReduzidoANC NUMBER;
nCdItemResTxAdm NUMBER;
nCdSetorTxAdm NUMBER;
cSnSegregacaoAtoTxAdm VARCHAR2(1);

pcd_multi_empresa NUMBER;

dDataInicial DATE;
dDataFinal DATE;

nCdSetorAux NUMBER;

BEGIN
  DBAPS.PRC_MVS_CHECA_PERIODO_CONTABIL ( dbamv.pkg_mv2000.le_empresa, To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) );

  IF psn_receita = 'S' THEN

    FOR R IN ( SELECT MC.cd_mens_contrato, MC.tp_receita, MC.dt_contabilizacao, MC.dt_inicio_cobertura, MC.dt_final_mensalidade, Min( MCR.DT_CREDITO ) dt_credito
                FROM dbaps.mens_contrato mc, DBAPS.MENS_CONTRATO_REC MCR
                WHERE mcr.cd_mens_contrato =  mc.cd_mens_contrato
                  AND to_char( mcr.dt_credito, 'yyyymm') >= PNR_MESANO_INICIAL
                  AND mc.cd_Exp_contabilidade_fa IS NULL
                  AND MC.dt_contabilizacao IS NULL
                GROUP BY MC.cd_mens_contrato, MC.tp_receita, MC.dt_contabilizacao, MC.dt_inicio_cobertura, MC.dt_final_mensalidade ) LOOP

      UPDATE DBAPS.MENS_CONTRATO
          SET DT_CONTABILIZACAO = R.DT_CREDITO
            ,DT_INICIO_COBERTURA = Nvl( DT_INICIO_COBERTURA, R.DT_CREDITO )
            ,DT_FINAL_MENSALIDADE = Nvl( DT_FINAL_MENSALIDADE, Add_Months( R.DT_CREDITO, 1 )-1 )
          WHERE CD_MENS_CONTRATO = R.CD_MENS_CONTRATO;

    END LOOP;

--    FOR r IN (
--              SELECT mc.cd_mens_contrato, mc.dt_contabilizacao, mc.dt_inicio_cobertura, mc.dt_final_mensalidade, mc.dt_emissao, Min( mcr.dt_credito ) dt_credito
--                FROM dbaps.mens_contrato mc, dbaps.mens_contrato_rec mcr
--                WHERE cd_exp_contabilidade_fa IS NULL
--                  AND dt_contabilizacao < To_Date(PNR_MESANO_INICIAL, 'yyyymm')
--                  AND EXISTS ( SELECT 1
--                                 FROM dbamv.lote
--                                 WHERE lote.ds_lote LIKE '%SAUDE%FTA%'||To_Char(mc.dt_contabilizacao, 'mm/yyyy')||'%' )
--                  AND mcr.cd_mens_contrato = mc.cd_mens_contrato
--                  AND mcr.dt_credito BETWEEN To_Date(PNR_MESANO_INICIAL, 'yyyymm') AND last_day(To_Date(PNR_MESANO_INICIAL, 'yyyymm'))
--                GROUP BY mc.cd_mens_contrato, mc.dt_contabilizacao, mc.dt_inicio_cobertura, mc.dt_final_mensalidade, mc.dt_emissao
--            ) LOOP

--      UPDATE dbaps.mens_contrato
--        SET dt_contabilizacao = r.dt_credito
--        WHERE cd_mens_contrato = r.cd_mens_contrato;

--    END LOOP;

--    FOR r IN (
--              SELECT mc.cd_mens_contrato, mc.dt_contabilizacao, mc.dt_inicio_cobertura, mc.dt_final_mensalidade, mc.dt_emissao, mc.dt_cancelamento
--                FROM dbaps.mens_contrato mc
--                WHERE cd_exp_contabilidade_fa IS NULL
--                  AND dt_contabilizacao < To_Date(PNR_MESANO_INICIAL, 'yyyymm')
--                  AND mc.dt_cancelamento BETWEEN To_Date(PNR_MESANO_INICIAL, 'yyyymm') AND last_day(To_Date(PNR_MESANO_INICIAL, 'yyyymm'))
--                  AND EXISTS ( SELECT 1
--                                 FROM dbamv.lote
--                                 WHERE lote.ds_lote LIKE '%SAUDE%FTA%'||To_Char(mc.dt_contabilizacao, 'mm/yyyy')||'%' )
--                  AND NOT EXISTS ( SELECT 1
--                                     FROM DBAPS.MOTIVOS_CANCELAMENTO MOT_CANC
--                                     WHERE MOT_CANC.CD_MOTIVO_CANCELAMENTO = MC.CD_MOTIVO_CANCELAMENTO
--                                     AND MOT_CANC.TP_CANCELAMENTO = 'A' )
--            ) LOOP

--      UPDATE dbaps.mens_contrato
--        SET dt_contabilizacao = r.dt_cancelamento
--        WHERE cd_mens_contrato = r.cd_mens_contrato;

--    END LOOP;

  END IF;

  IF Nvl( DBAPS.FNC_MVS_RETORNA_VALOR_CONFIG('CONTABIL_DSP_SN_NOVO_REPASSE'), 'N' ) = 'N' THEN
    DBAPS.PRC_IDENT_CTACTB_CUSTOS_ANTER( PNR_MESANO_INICIAL
                                        ,PNR_MESANO_FINAL
                                        ,PSN_DESPESA
                                        ,PSN_RECEITA
                                        ,PSN_CUSTO
                                        ,PCD_MENS_CONTRATO
                                        ,PCD_FATURA
                                        ,PCD_PRESTADOR
                                        ,PCD_REEMBOLSO );
    RETURN;
  END IF;

  DBAPS.PKG_SOULSAUDE.ATRIBUI_MODO_IMPORTA_XML('S');
  pcd_multi_empresa := dbamv.pkg_mv2000.le_empresa;

  IF psn_despesa = 'S' THEN

    FOR R IN ( SELECT decode( vcm.tp_fatura, 'R', 'A520', 'PAGAMENTO AO PRESTADOR' ) TP_FATURA,
                      Nvl( To_Char( vcm.cd_matricula ), vcm.nr_carteira_beneficiario ) cd_matricula,
                      Decode( vcm.tp_conta, 'A', 'AMBULATORIAL', 'INTERNACAO' ) tp_conta,
                      vcm.cd_conta_medica,
                      vcm.cd_lancamento_filho,
                      vcm.cd_procedimento_digitado,
                      vcm.ds_procedimento,
                      vcm.vl_total_cobrado
                 FROM dbaps.v_ctaS_medicas vcm
                 WHERE vcm.dt_competencia = PNR_MESANO_INICIAL
                   AND vcm.cd_multi_empresa = dbamv.pkg_mv2000.le_empresa
                   AND vcm.tp_fatura <> 'R'
                   AND NOT EXISTS ( SELECT 1 FROM dbaps.procedimento p WHERE vcm.cd_procedimento = p.cd_procedimento )
                  AND vcm.tp_situacao <> 'NA' ) LOOP

      IF r.tp_conta = 'AMBULATORIAL' THEN
        UPDATE dbaps.itremessa_prestador i
           SET cd_procedimento = '-1'
           WHERE cd_remessa = r.cd_conta_medica
             AND cd_lancamento = r.cd_lancamento_filho
             AND cd_proc_digita = r.cd_procedimento_digitado
             AND NOT EXISTS ( SELECT 1 FROM dbaps.procedimento p WHERE p.cd_procedimento = i.cd_procedimento );
      ELSE
        UPDATE dbaps.itconta_hospitalar i
           SET cd_procedimento = '-1'
           WHERE cd_conta_hospitalar = r.cd_conta_medica
             AND cd_lancamento = r.cd_lancamento_filho
             AND cd_proc_digita = r.cd_procedimento_digitado
             AND NOT EXISTS ( SELECT 1 FROM dbaps.procedimento p WHERE p.cd_procedimento = i.cd_procedimento );
      END IF;

    END LOOP;

  END IF;

  UPDATE dbaps.contrato c
    SET cd_plano = ( SELECT Min(cd_plano) FROM dbaps.plano_contrato pc WHERE c.cd_contrato = pc.cd_contrato )
    WHERE cd_plano IS NULL
      AND tp_contrato IN ( 'I', 'F', 'E', 'A' )
      AND cd_multi_empresa = pcd_multi_empresa
      AND ( ( tp_contrato IN ('I', 'F', 'A' ) AND cd_matricula IS NOT NULL ) OR ( tp_contrato NOT IN ('I', 'F', 'A' ) AND cd_empresa IS NOT NULL ) );


  nCdTaxaAdmUnimed := NULL;
  nCdReduzidoReceitaTxAdm := NULL;
  nCdReduzidoAtivoTxAdm := NULL;
  nCdReduzidoCancTxAdm := NULL;
  nCdReduzidoFATxAdm := NULL;
  nCdReduzidoACP := NULL;
  nCdReduzidoACA := NULL;
  nCdReduzidoANC := NULL;
  nCdItemResTxAdm := NULL;
  nCdSetorTxAdm := NULL;

  nCdGrupoFranquia := NULL;

  OPEN  cGrupoFranquia;
  FETCH cGrupoFranquia INTO nCdGrupoFranquia;
  CLOSE cGrupoFranquia;

  IF DBAPS.PKG_UNIMED.LE_UNIMED IS NOT NULL AND PSN_RECEITA = 'S' THEN
    OPEN  cPercAto;
    FETCH cPercAto INTO nVlPercAP, nVlPercAA, nVlPercNC;

    IF cPercAto%NOTFOUND THEN
      DBAPS.PRC_MVS_CONSOLIDA_ATOS( DBAMV.PKG_MV2000.LE_EMPRESA, Trunc( To_Date(PNR_MESANO_INICIAL, 'YYYYMM'), 'MM'), Add_Months( Trunc( To_Date(PNR_MESANO_INICIAL, 'YYYYMM'), 'MM'), -1 ) );
    END IF;

    CLOSE cPercAto;

  END IF;

/*
EXECUCAO DA ATUALIZACAO ABAIXO Ã¿ PROVISIORIA ENQUANTO NAO SE DESCOBRE A CAUSA
DESSE ERRO AO RECEBER A MENSALIDADE COM ACRESCIMOS OU DESCONTOS
*/

--  IF PSN_RECEITA = 'S' THEN

--    FOR r IN ( SELECT MCR.CD_MENS_CONTRATO_REC,
--                      MCR.DT_CREDITO,
--                      MCR.VL_ACRESCIMO,
--                      MCRL.VL_ACRESCIMO VL_ACRES_MCRL,
--                      MCR.VL_DESCONTO,
--                      MCRL.VL_DESCONTO VL_DESCONTO_MCRL
--                 FROM DBAPS.MENS_CONTRATO_REC MCR,
--                      ( SELECT CD_MENS_CONTRATO_REC,
--                               Sum(Decode(LM.TP_OPERACAO, 'D', 0, MCRL.VL_LANCAMENTO) ) VL_ACRESCIMO,
--                               Sum(Decode(LM.TP_OPERACAO, 'D', MCRL.VL_LANCAMENTO, 0) ) VL_DESCONTO
--                          FROM DBAPS.MEN_CON_REC_LCTO MCRL, DBAPS.LCTO_MENSALIDADE LM
--                          WHERE MCRL.CD_LCTO_MENSALIDADE = LM.CD_LCTO_MENSALIDADE
--                          GROUP BY CD_MENS_CONTRATO_REC )  MCRL
--                 WHERE MCR.CD_MENS_CONTRATO_REC = MCRL.CD_MENS_CONTRATO_REC
--                   AND MCR.DT_CREDITO >= To_Date(PNR_MESANO_INICIAL, 'YYYYMM')
--                   AND ( Nvl( MCR.VL_ACRESCIMO, 0 ) <> Nvl( MCRL.VL_ACRESCIMO, 0 ) OR Nvl( MCR.VL_DESCONTO, 0 ) <> Nvl( MCRL.VL_DESCONTO, 0 ) )
--                 ORDER BY 2 DESC ) LOOP

--      IF Nvl( R.VL_ACRESCIMO, 0 ) <> Nvl( R.VL_ACRES_MCRL, 0 ) THEN
--        UPDATE DBAPS.MENS_CONTRATO_REC
--           SET VL_ACRESCIMO = R.VL_ACRES_MCRL
--              ,VL_MENS_REAL = VL_MENS_REAL
--           WHERE CD_MENS_CONTRATO_REC = R.CD_MENS_CONTRATO_REC;
--      END IF;

--      IF Nvl( R.VL_DESCONTO, 0 ) <> Nvl( R.VL_DESCONTO_MCRL, 0 ) THEN
--        UPDATE DBAPS.MENS_CONTRATO_REC
--           SET VL_DESCONTO = R.VL_DESCONTO_MCRL
--              ,VL_MENS_REAL = VL_MENS_REAL
--           WHERE CD_MENS_CONTRATO_REC = R.CD_MENS_CONTRATO_REC;
--      END IF;

--    END LOOP;

--    BEGIN
--      FOR R IN ( SELECT MC.CD_MENS_CONTRATO,
--                        MC.DT_EMISSAO,
--                        MC.DT_CONTABILIZACAO,
--                        MC.DT_INICIO_COBERTURA,
--                        MCR.DT_CREDITO
--                   FROM DBAPS.MENS_CONTRATO MC,
--                        DBAPS.MENS_CONTRATO_REC MCR
--                   WHERE MC.DT_EMISSAO = MC.DT_CONTABILIZACAO
--                     AND 1 = ( SELECT Count(*)
--                                 FROM DBAPS.MENS_CONTRATO_REC MCR2
--                                 WHERE MCR2.CD_MENS_CONTRATO=MC.CD_MENS_CONTRATO )
--                     AND Trunc(MC.DT_EMISSAO, 'MM') > Trunc(MC.DT_INICIO_COBERTURA, 'MM')
--                     AND MC.CD_MULTI_EMPRESA = DBAMV.PKG_MV2000.LE_EMPRESA
--                     AND MC.DT_CONTABILIZACAO >= To_Date(PNR_MESANO_INICIAL, 'YYYYMM')
--                     AND MC.CD_MENS_CONTRATO = MCR.CD_MENS_CONTRATO
----                     AND MC.CD_EXP_CONTABILIDADE_FA IS NULL
--                     AND NOT EXISTS ( SELECT 1
--                                        FROM DBAMV.LOTE L
--                                        WHERE L.CD_MULTI_EMPRESA = MC.CD_MULTI_EMPRESA
--                                          AND L.DT_INICIAL_LCTO <= MC.DT_INICIO_COBERTURA
--                                          AND L.DS_LOTE LIKE '%FTA%'
--                                          AND L.DT_FINAL_LCTO >= MC.DT_INICIO_COBERTURA ) ) LOOP

--        UPDATE DBAPS.MENS_CONTRATO
--           SET /*DT_EMISSAO = R.DT_INICIO_COBERTURA
--              ,DT_VENCIMENTO_ORIGINAL = R.DT_INICIO_COBERTURA
--              ,*/DT_CONTABILIZACAO = R.DT_INICIO_COBERTURA
--              ,DT_INCLUSAO = R.DT_INICIO_COBERTURA
--           WHERE CD_MENS_CONTRATO = R.CD_MENS_CONTRATO;
--      END LOOP;

--    END;

--  END IF;

  nCdGrupoFranquia := NULL;
  cTpProvisaoReceita := 'FTA';
  BEGIN
  	SELECT PS.CD_GRUPO_FRANQUIA, LM.TP_LOTE_CONTABIL_PROVISAO
	    INTO nCdGrupoFranquia, cTpProvisaoReceita
		  FROM DBAPS.PLANO_DE_SAUDE PS, DBAPS.LCTO_MENSALIDADE LM
      WHERE PS.CD_GRUPO_FRANQUIA = LM.CD_LCTO_MENSALIDADE;
  EXCEPTION
    WHEN OTHERS THEN
    	nCdGrupoFranquia := NULL;
      cTpProvisaoReceita := 'FTA';
  END;

  IF PSN_RECEITA = 'S' THEN

    FOR rGF IN cGlosaFaturamento LOOP

			nCdReduzido := dbaps.fnc_conta_contabil_despesa
							       ( rGF.CD_MATRICULA
						          ,rGF.CD_PRESTADOR
							        ,rGF.TP_GUIA
							        ,rGF.CD_PROCEDIMENTO
							        ,'GFD'
							        ,cCdSetor
							        ,cCdItemRes
                      ,NULL
                      ,rGF.CD_PLANO
                      ,rGF.DT_GERACAO );

			nCdReduzido3 := dbaps.fnc_conta_contabil_despesa
							       ( rGF.CD_MATRICULA
						          ,rGF.CD_PRESTADOR
							        ,rGF.TP_GUIA
							        ,rGF.CD_PROCEDIMENTO
							        ,'GFC'
							        ,cCdSetor
							        ,cCdItemRes
                      ,NULL
                      ,rGF.CD_PLANO
                      ,rGF.DT_GERACAO );

      IF rGF.TP_CONTA = 'A' THEN
        UPDATE DBAPS.ITREMESSA_PRESTADOR_FATURA
           SET CD_SETOR = cCdSetor,
               CD_ITEM_RES = cCdItemRes,
               CD_REDUZIDO_GLOSA_DEBITO = nCdReduzido,
               CD_REDUZIDO_GLOSA_CREDITO = nCdReduzido3
           WHERE CD_REMESSA = rGF.CD_CONTA_MEDICA
             AND CD_LANCAMENTO = rGF.CD_LANCAMENTO;
      ELSE
        UPDATE DBAPS.ITCONTA_HOSPITALAR_FATURA
           SET CD_SETOR = cCdSetor,
               CD_ITEM_RES = cCdItemRes,
               CD_REDUZIDO_GLOSA_DEBITO = nCdReduzido,
               CD_REDUZIDO_GLOSA_CREDITO = nCdReduzido3
           WHERE CD_CONTA_HOSPITALAR = rGF.CD_CONTA_MEDICA
             AND CD_LANCAMENTO = rGF.CD_LANCAMENTO;
      END IF;

    END LOOP;

    FOR rDevolucao IN cDevolucao ( DBAMV.PKG_MV2000.LE_EMPRESA ) LOOP
      nCdReduzido  := DBAPS.FNC_CONTA_CONTABIL_RECEITA( rDevolucao.cd_matricula, rDevolucao.CD_LCTO_MENSALIDADE, 'CE', nCdSetor, nCdItemRes, nCdReduzido2, rDevolucao.cd_plano, rDevolucao.DT_VIGENCIA );
      nCdReduzido3 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( rDevolucao.cd_matricula, rDevolucao.CD_LCTO_MENSALIDADE, 'FA', nCdSetor, nCdItemRes, nCdReduzido2, rDevolucao.cd_plano, rDevolucao.DT_VIGENCIA );

      IF rDevolucao.dt_cancelamento IS NOT NULL then
        nCdReduzido4 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( rDevolucao.cd_matricula, rDevolucao.CD_LCTO_MENSALIDADE, 'CC', nCdSetor, nCdItemRes, nCdReduzido2, rDevolucao.cd_plano,rDevolucao.DT_VIGENCIA );
      ELSE
        nCdReduzido4 := NULL;
      END IF;

      nCdReduzido5 := NULL;
      nCdReduzido6 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( rDevolucao.cd_matricula, rDevolucao.CD_LCTO_MENSALIDADE, 'AT', nCdSetor, nCdItemRes, nCdReduzido2, rDevolucao.cd_plano, rDevolucao.DT_VIGENCIA );

      IF rDevolucao.tp_lancamento = 'FTA' THEN
        UPDATE DBAPS.ITREEMBOLSO
          SET CD_REDUZIDO_CE = nCdReduzido
              ,CD_REDUZIDO_FA = nCdReduzido3
              ,CD_REDUZIDO_CC = nCdReduzido4
              ,CD_REDUZIDO_CA = nCdReduzido5
              ,CD_SETOR = nCdSetor
              ,CD_ITEM_RES = nCdItemRes
              ,CD_REDUZIDO_ATIVO = nCdReduzido6
          WHERE CD_REEMBOLSO = rDevolucao.cd_reembolso
            AND CD_PROCEDIMENTO = rDevolucao.cd_procedimento
            AND CD_LCTO_MENSALIDADE = rDevolucao.cd_lcto_mensalidade;
      ELSE
        UPDATE DBAPS.ITREEMBOLSO
          SET  CD_REDUZIDO_CC = nCdReduzido4
          WHERE CD_REEMBOLSO = rDevolucao.cd_reembolso
            AND CD_PROCEDIMENTO = rDevolucao.cd_procedimento
            AND CD_LCTO_MENSALIDADE = rDevolucao.cd_lcto_mensalidade;
      END IF;

    END LOOP;
    FOR rMensContrato IN cMensContrato ( DBAMV.PKG_MV2000.LE_EMPRESA ) LOOP

      nCdTaxaAdmUnimed := NULL;

      FOR rCCR IN ( SELECT CD_LCTO_MENSALIDADE_TAXA_ADM FROM DBAPS.CONFIG_CONTRATO_RECEITA WHERE CD_CONTRATO = rMensContrato.CD_CONTRATO AND CD_LCTO_MENSALIDADE_TAXA_ADM IS NOT NULL ) LOOP
        BEGIN
          SELECT b.cd_lcto_mensalidade,
                 b.sn_segregacao_ato
            INTO nCdTaxaAdmUnimed, cSnSegregacaoAtoTxAdm
            FROM dbaps.lcto_mensalidade b
            WHERE b.cd_lcto_mensalidade = rCCR.cd_lcto_mensalidade_taxa_adm;
        EXCEPTION
          WHEN OTHERS THEN
            nCdTaxaAdmUnimed := NULL;
            cSnSegregacaoAtoTxAdm := 'N';
        END;
      END LOOP;

      IF nCdTaxaAdmUnimed IS NULL THEN
        BEGIN
          SELECT a.cd_lcto_mensalidade_taxa_adm,
                b.sn_segregacao_ato
            INTO nCdTaxaAdmUnimed, cSnSegregacaoAtoTxAdm
            FROM dbamv.multi_empresas_mv_saude a,
                dbaps.lcto_mensalidade b
            WHERE a.cd_multi_empresa = dbamv.pkg_mv2000.le_empresa
              AND a.cd_lcto_mensalidade_taxa_adm = b.cd_lcto_mensalidade;
        EXCEPTION
          WHEN OTHERS THEN
            nCdTaxaAdmUnimed := NULL;
            cSnSegregacaoAtoTxAdm := 'N';
        END;
      END IF;


      cExisteLctoRecebimento := 'N';
      nCdMensContrato := NULL;

      IF rMensContrato.TP_RECEITA  = 'F' THEN
        OPEN  cLctoRecebimento ( rMensContrato.CD_MENS_CONTRATO );
        FETCH cLctoRecebimento INTO nCdMensContrato;

        IF cLctoRecebimento%NOTFOUND THEN
          cExisteLctoRecebimento := 'N';
        ELSE
          cExisteLctoRecebimento := 'S';
        END IF;

        CLOSE cLctoRecebimento;

      END IF;

      IF ( rMensContrato.TP_RECEITA <> 'F' OR ( rMensContrato.TP_RECEITA  = 'F' AND cExisteLctoRecebimento = 'S' ) ) THEN

	      FOR rReceitas IN cReceitas ( DBAMV.PKG_MV2000.LE_EMPRESA, rMensContrato.CD_MENS_CONTRATO ) LOOP

	        nCdPlano := rReceitas.CD_PLANO;
   	      nCdMatricula := NULL;

          nCdReduzido := NULL;
          nCdReduzido2 := NULL;
          nCdReduzido3 := NULL;
          nCdReduzido4 := NULL;
          nCdReduzido5 := NULL;
          nCdReduzido6 := NULL;

          nCdReduzidoAtoPrincipal := NULL;
          nCdReduzidoAtoAuxiliar := NULL;
          nCdReduzidoAtoNaoCoop := NULL;

          nCdSetor := NULL;
          nCdItemRes := NULL;
          cCdSetor := NULL;
          cCdItemRes := NULL;

          nCdReduzido3 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'FA', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano, rReceitas.DT_VIGENCIA );
          nCdReduzido4 := NULL;
          nCdReduzido5 := NULL;
          nCdReduzido6 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'AT', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano, rReceitas.DT_VIGENCIA ); --PDA: 444448

          IF rReceitas.DT_CANCELAMENTO IS NOT NULL THEN

            IF rReceitas.DT_INICIO_COBERTURA IS NULL THEN
              dDtInicioCobertura := dbaps.fnc_data_inicio_cobertura(rReceitas.Cd_Contrato, To_Date('01'||'/'||rReceitas.NR_MES || '/' || rReceitas.NR_ANO, 'dd/mm/yyyy'));
            ELSE
              dDtInicioCobertura := rReceitas.DT_INICIO_COBERTURA;
            END IF;

            IF ( TO_CHAR( rReceitas.DT_CANCELAMENTO, 'YYYYMM' ) >= To_Char( rReceitas.DT_FINAL_MENSALIDADE, 'YYYYMM') ) OR rReceitas.SN_PRORATA='N' THEN
              nCdReduzido4 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'CC', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
            ELSIF rReceitas.DT_CANCELAMENTO < dDtInicioCobertura THEN
              nCdReduzido5 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'CA', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
            ELSIF rReceitas.DT_CANCELAMENTO > dDtInicioCobertura OR Trunc(rReceitas.DT_CANCELAMENTO,'MM') = Trunc(dDtInicioCobertura,'MM') THEN
              nCdReduzido4 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'CC', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
              nCdReduzido5 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'CA', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
            ELSE
              nCdReduzido4 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'CC', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
            END IF;
          END IF;

          BEGIN
            SELECT SN_CONTABILIZA
              INTO cSnContabiliza
              FROM DBAPS.LCTO_MENSALIDADE
 	            WHERE CD_LCTO_MENSALIDADE = rReceitas.CD_LCTO_MENSALIDADE;
          EXCEPTION
            WHEN OTHERS THEN
              cSnContabiliza := 'S';
          END;

		      nCdReduzido := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'CE', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );

          IF DBAPS.PKG_UNIMED.LE_UNIMED IS NOT NULL AND rReceitas.SN_SEGREGACAO_ATO = 'S' AND cSnContabiliza = 'S' THEN
            nCdReduzidoAtoPrincipal := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'AP', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
            nCdReduzidoAtoAuxiliar := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'AA', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
            nCdReduzidoAtoNaoCoop := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rReceitas.CD_LCTO_MENSALIDADE, 'AN', nCdSetor, nCdItemRes, nCdReduzido2, nCdPlano,rReceitas.DT_VIGENCIA );
          ELSE
            nCdReduzidoAtoPrincipal := NULL;
            nCdReduzidoAtoAuxiliar := NULL;
            nCdReduzidoAtoNaoCoop := NULL;
          END IF;

	        IF nCdGrupoFranquia = rReceitas.CD_LCTO_MENSALIDADE AND cSnContabiliza = 'N' THEN

		        FOR rItGuia IN cItGuia( rReceitas.CD_MENS_CONTRATO ) LOOP
			        cCdSetor := NULL;
			        cCdItemRes := NULL;
			        nCdReduzido := dbaps.fnc_conta_contabil_despesa
							        ( NULL --nCdMatricula
							        ,rItGuia.CD_PRESTADOR_EXECUTOR
							        ,rItGuia.TP_GUIA
							        ,rItGuia.CD_PROCEDIMENTO
							        ,'CR'
							        ,cCdSetor
							        ,cCdItemRes
                      ,NULL
                      ,nCdPlano
                      ,rReceitas.DT_VIGENCIA );

              nCdReduzido4 := nCdReduzido;
              nCdReduzido5 := nCdReduzido;

              IF rItGuia.tp_origem = 'G' THEN

                IF rItGuia.cd_itguia_ctactb IS NULL AND nCdReduzido IS NOT NULL THEN
				            INSERT INTO DBAPS.ITGUIA_CTACTB
							            (cd_itguia_ctactb
							            ,cd_itguia
							            ,cd_reduzido_ce
							            ,cd_reduzido_cc
							            ,cd_setor
							            ,cd_item_res
							            ,cd_reduzido_fa
							            ,cd_reduzido_ativo
							            ,cd_reduzido_ca
                          ,cd_lcto_mensalidade)
						            VALUES
							            (DBAPS.SEQ_ITGUIA_CTACTB.NEXTVAL
							            ,rItGuia.cd_itguia
							            ,nCdReduzido
							            ,nCdReduzido4
							            ,nCdSetor
							            ,nCdItemRes
							            ,nCdReduzido3
							            ,nCdReduzido6
							            ,nCdReduzido5
							            ,rReceitas.CD_LCTO_MENSALIDADE);
			            ELSE

				            IF nCdReduzido IS NOT NULL THEN
					            UPDATE DBAPS.ITGUIA_CTACTB
						            SET CD_REDUZIDO_CE = nCdReduzido
						              ,CD_SETOR = nCdSetor
                          ,CD_REDUZIDO_CA = nCdReduzido5
                          ,CD_REDUZIDO_FA = nCdReduzido3
							            ,CD_REDUZIDO_ATIVO = nCdReduzido6
						              ,CD_ITEM_RES = nCdItemRes
                          ,CD_REDUZIDO_CC = nCdReduzido4
					              WHERE cd_itguia_ctactb = rItGuia.cd_itguia_ctactb;
				            END IF;
			            END IF;

              ELSIF rItGuia.tp_origem = 'M' THEN

                IF nCdReduzido IS NOT NULL THEN
					        UPDATE DBAPS.CONTAS_MEDICAS_MENS_CONTRATO
						        SET CD_REDUZIDO_CE = nCdReduzido
						          ,CD_SETOR = nCdSetor
                      ,CD_REDUZIDO_CA = nCdReduzido5
                      ,CD_REDUZIDO_FA = nCdReduzido3
							        ,CD_REDUZIDO_ATIVO = nCdReduzido6
						          ,CD_ITEM_RES = nCdItemRes
                      ,CD_REDUZIDO_CC = nCdReduzido4
					          WHERE cd_conta_medica = rItGuia.cd_conta_medica
                      AND cd_lancamento_filho = rItGuia.cd_lancamento
                      AND TP_CONTA = rItGuia.tp_conta;
				        END IF;

              END IF;
		        END LOOP;

		      END IF;

          FOR rMU IN ( SELECT MU.CD_MENS_USUARIO, MU.CD_MATRICULA, MU.CD_MAT_ALTERNATIVA
                            FROM DBAPS.MENS_USUARIO MU, DBAPS.CONTRATO CT
                            WHERE MU.CD_MENS_CONTRATO = rReceitas.CD_MENS_CONTRATO
                              AND MU.CD_CONTRATO = CT.CD_CONTRATO
                              AND Nvl( MU.CD_PLANO, Nvl(CT.CD_PLANO, -1 ) ) = Nvl( nCdPlano, -1 )  )  LOOP

            UPDATE DBAPS.ITMENS_USUARIO IMU
              SET CD_REDUZIDO_CE = nCdReduzido
                  ,CD_REDUZIDO_FA = nCdReduzido3
                  ,CD_REDUZIDO_CC = nCdReduzido4
                  ,CD_REDUZIDO_CA = nCdReduzido5
                  ,CD_REDUZIDO_ATO_PRINCIPAL = nCdReduzidoAtoPrincipal
                  ,CD_REDUZIDO_ATO_AUXILIAR = nCdReduzidoAtoAuxiliar
                  ,CD_REDUZIDO_ATO_NAO_COOP = nCdReduzidoAtoNaoCoop
                  ,VL_ATO_PRINCIPAL = ( VL_LANCAMENTO * ( nVlPercAP / 100 ) )
                  ,VL_ATO_AUXILIAR = ( VL_LANCAMENTO * ( nVlPercAA / 100 ) )
                  ,VL_ATO_NAO_COOP = ( VL_LANCAMENTO * ( nVlPercNC / 100 ) )
                  ,VL_RECEITA_ATO_PRINCIPAL = ( VL_RECEITA * ( nVlPercAP / 100 ) )
                  ,VL_RECEITA_ATO_AUXILIAR = ( VL_RECEITA * ( nVlPercAA / 100 ) )
                  ,VL_RECEITA_ATO_NAO_COOP = ( VL_RECEITA * ( nVlPercNC / 100 ) )
                  ,VL_FAT_ANTECIP_ATO_PRINCIPAL = ( VL_FATURAMENTO_ANTECIPADO * ( nVlPercAP / 100 ) )
                  ,VL_FAT_ANTECIP_ATO_AUXILIAR = ( VL_FATURAMENTO_ANTECIPADO * ( nVlPercAA / 100 ) )
                  ,VL_FAT_ANTECIP_ATO_NAO_COOP = ( VL_FATURAMENTO_ANTECIPADO * ( nVlPercNC / 100 ) )
                  ,CD_SETOR = nCdSetor
                  ,CD_ITEM_RES = nCdItemRes
                  ,CD_REDUZIDO_ATIVO = nCdReduzido6
              WHERE CD_LCTO_MENSALIDADE = rReceitas.CD_LCTO_MENSALIDADE
                AND CD_MENS_USUARIO = rMU.CD_MENS_USUARIO
                AND EXISTS ( SELECT 1
                              FROM DBAPS.MENS_CONTRATO MC,
                                    DBAPS.MENS_USUARIO MU
                              WHERE MC.CD_MENS_CONTRATO = MU.CD_MENS_CONTRATO
                                AND MC.CD_EXP_CONTABILIDADE_FA IS NULL
                                AND MU.CD_MENS_USUARIO = IMU.CD_MENS_USUARIO );


            UPDATE DBAPS.ITMENS_USUARIO IMU
              SET CD_REDUZIDO_CC = nCdReduzido4
                ,CD_REDUZIDO_CA = nCdReduzido5
              WHERE CD_LCTO_MENSALIDADE = rReceitas.CD_LCTO_MENSALIDADE
                AND CD_MENS_USUARIO = rMU.CD_MENS_USUARIO
                AND EXISTS ( SELECT 1
                              FROM DBAPS.MENS_CONTRATO MC,
                                    DBAPS.MENS_USUARIO MU
                              WHERE MC.CD_MENS_CONTRATO = MU.CD_MENS_CONTRATO
                                AND MC.CD_EXP_CONTABILIDADE_FA IS NOT NULL
                                AND MC.CD_EXP_CONTABILIDADE_CANC IS NULL
                                AND MU.CD_MENS_USUARIO = IMU.CD_MENS_USUARIO );

          END LOOP;

          UPDATE DBAPS.ITMENS_CONTRATO
            SET CD_REDUZIDO_CE = nCdReduzido
                ,CD_REDUZIDO_FA = nCdReduzido3
                ,CD_REDUZIDO_CC = nCdReduzido4
                ,CD_REDUZIDO_CA = nCdReduzido5
                ,CD_REDUZIDO_ATIVO = nCdReduzido6
                ,CD_REDUZIDO_ATO_PRINCIPAL = nCdReduzidoAtoPrincipal
                ,CD_REDUZIDO_ATO_AUXILIAR = nCdReduzidoAtoAuxiliar
                ,CD_REDUZIDO_ATO_NAO_COOP = nCdReduzidoAtoNaoCoop
                ,VL_ATO_PRINCIPAL = ( VL_LANCAMENTO * ( nVlPercAP / 100 ) )
                ,VL_ATO_AUXILIAR = ( VL_LANCAMENTO * ( nVlPercAA / 100 ) )
                ,VL_ATO_NAO_COOP = ( VL_LANCAMENTO * ( nVlPercNC / 100 ) )
                ,VL_RECEITA_ATO_PRINCIPAL = ( VL_RECEITA * ( nVlPercAP / 100 ) )
                ,VL_RECEITA_ATO_AUXILIAR = ( VL_RECEITA * ( nVlPercAA / 100 ) )
                ,VL_RECEITA_ATO_NAO_COOP = ( VL_RECEITA * ( nVlPercNC / 100 ) )
                ,VL_FAT_ANTECIP_ATO_PRINCIPAL = ( VL_FATURAMENTO_ANTECIPADO * ( nVlPercAP / 100 ) )
                ,VL_FAT_ANTECIP_ATO_AUXILIAR = ( VL_FATURAMENTO_ANTECIPADO * ( nVlPercAA / 100 ) )
                ,VL_FAT_ANTECIP_ATO_NAO_COOP = ( VL_FATURAMENTO_ANTECIPADO * ( nVlPercNC / 100 ) )
                ,CD_SETOR = nCdSetor
                ,CD_ITEM_RES = nCdItemRes
            WHERE CD_MENS_CONTRATO = rReceitas.CD_MENS_CONTRATO
              AND CD_LCTO_MENSALIDADE = rReceitas.CD_LCTO_MENSALIDADE
              AND Nvl( SN_LCTO_RECEBIMENTO, 'N' ) = 'N'
              AND EXISTS ( SELECT 1
                            FROM DBAPS.MENS_CONTRATO MC
                            WHERE MC.CD_MENS_CONTRATO = ITMENS_CONTRATO.CD_MENS_CONTRATO
                              AND MC.CD_EXP_CONTABILIDADE_FA IS NULL );

          UPDATE DBAPS.ITMENS_CONTRATO
            SET CD_REDUZIDO_CC = nCdReduzido4
              ,CD_REDUZIDO_CA = nCdReduzido5
            WHERE CD_MENS_CONTRATO = rReceitas.CD_MENS_CONTRATO
              AND CD_LCTO_MENSALIDADE = rReceitas.CD_LCTO_MENSALIDADE
              AND Nvl( SN_LCTO_RECEBIMENTO, 'N' ) = 'N'
              AND EXISTS ( SELECT 1
                                FROM DBAPS.MENS_CONTRATO MC
                                WHERE MC.CD_MENS_CONTRATO = ITMENS_CONTRATO.CD_MENS_CONTRATO
                                  AND MC.CD_EXP_CONTABILIDADE_CANC IS NULL
                                  AND MC.DT_CANCELAMENTO IS NOT NULL
                                  AND MC.CD_EXP_CONTABILIDADE_FA IS NOT NULL );

          UPDATE DBAPS.ITMENS_CONTRATO
            SET CD_REDUZIDO_CE = nCdReduzido
                ,CD_REDUZIDO_FA = nCdReduzido3
                ,CD_REDUZIDO_ATIVO = nCdReduzido6
                ,CD_REDUZIDO_ATO_PRINCIPAL = nCdReduzidoAtoPrincipal
                ,CD_REDUZIDO_ATO_AUXILIAR = nCdReduzidoAtoAuxiliar
                ,CD_REDUZIDO_ATO_NAO_COOP = nCdReduzidoAtoNaoCoop
                ,VL_ATO_PRINCIPAL = ( VL_LANCAMENTO * ( nVlPercAP / 100 ) )
                ,VL_ATO_AUXILIAR = ( VL_LANCAMENTO * ( nVlPercAA / 100 ) )
                ,VL_ATO_NAO_COOP = ( VL_LANCAMENTO * ( nVlPercNC / 100 ) )
                ,CD_SETOR = nCdSetor
                ,CD_ITEM_RES = nCdItemRes
            WHERE CD_MENS_CONTRATO = rReceitas.CD_MENS_CONTRATO
              AND CD_LCTO_MENSALIDADE = rReceitas.CD_LCTO_MENSALIDADE
              AND Nvl( SN_LCTO_RECEBIMENTO, 'N' ) = 'S';

	      END LOOP;

      END IF;

      IF rMensContrato.TP_RECEITA = 'F' THEN
        nCdPlano := NULL;
        FOR rCfg IN ( SELECT DISTINCT ID.CD_ITEM_DESPESA, ID.TP_CREDENCIAMENTO, LM.CD_LCTO_MENSALIDADE, LM.SN_SEGREGACAO_ATO, LM.SN_CONTABILIZA
                        FROM DBAPS.ITEM_DESPESA_A500 ID, DBAPS.LCTO_MENSALIDADE LM
                        WHERE ID.CD_LCTO_MENSALIDADE = LM.CD_LCTO_MENSALIDADE ) LOOP

          nCdSetor := NULL;
          nCdItemRes := NULL;
          cCdSetor := NULL;
          cCdItemRes := NULL;

          nCdReduzido  := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, rCfg.CD_LCTO_MENSALIDADE, 'CE', nCdSetor, nCdItemRes, nCdReduzido2, -1, Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
          nCdReduzido3 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, rCfg.CD_LCTO_MENSALIDADE, 'CC', nCdSetor, nCdItemRes, nCdReduzido2, -1, Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
          nCdReduzido4 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, rCfg.CD_LCTO_MENSALIDADE, 'FA', nCdSetor, nCdItemRes, nCdReduzido2, -1, Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );

          IF DBAPS.PKG_UNIMED.LE_UNIMED IS NOT NULL AND rCfg.SN_SEGREGACAO_ATO = 'S' AND rCfg.SN_CONTABILIZA = 'S' THEN
            nCdReduzidoAtoPrincipal := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rCfg.CD_LCTO_MENSALIDADE, 'AP', nCdSetor, nCdItemRes, nCdReduzido2, -1, Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
            nCdReduzidoAtoAuxiliar := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rCfg.CD_LCTO_MENSALIDADE, 'AA', nCdSetor, nCdItemRes, nCdReduzido2, -1, Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
            nCdReduzidoAtoNaoCoop := DBAPS.FNC_CONTA_CONTABIL_RECEITA( nCdMatricula, rCfg.CD_LCTO_MENSALIDADE, 'AN', nCdSetor, nCdItemRes, nCdReduzido2, -1, Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
          ELSE
            nCdReduzidoAtoPrincipal := NULL;
            nCdReduzidoAtoAuxiliar := NULL;
            nCdReduzidoAtoNaoCoop := NULL;
          END IF;

          nCdReduzidoCancTxAdm := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdTaxaAdmUnimed, 'CC', nCdSetorTxAdm, nCdItemResTxAdm, nCdReduzidoAtivoTxAdm, Nvl( nCdPlano, -1 ), Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
          nCdReduzidoFATxAdm := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdTaxaAdmUnimed, 'FA', nCdSetorTxAdm, nCdItemResTxAdm, nCdReduzidoAtivoTxAdm, Nvl( nCdPlano, -1 ), Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
          nCdReduzidoReceitaTxAdm := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdTaxaAdmUnimed, 'CE', nCdSetorTxAdm, nCdItemResTxAdm, nCdReduzidoAtivoTxAdm, Nvl( nCdPlano, -1 ), Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );

          IF cSnSegregacaoAtoTxAdm = 'S' THEN
            nCdReduzidoACP := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdTaxaAdmUnimed, 'AP', nCdSetorTxAdm, nCdItemResTxAdm, nCdReduzidoAtivoTxAdm, Nvl( nCdPlano, -1 ), Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
            nCdReduzidoACA := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdTaxaAdmUnimed, 'AA', nCdSetorTxAdm, nCdItemResTxAdm, nCdReduzidoAtivoTxAdm, Nvl( nCdPlano, -1 ), Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
            nCdReduzidoANC := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdTaxaAdmUnimed, 'AN', nCdSetorTxAdm, nCdItemResTxAdm, nCdReduzidoAtivoTxAdm, Nvl( nCdPlano, -1 ), Last_Day( To_Date( PNR_MESANO_INICIAL, 'YYYYMM' ) ) );
          ELSE
            nCdReduzidoACP := NULL;
            nCdReduzidoACA := NULL;
            nCdReduzidoANC := NULL;
          END IF;

          UPDATE dbaps.itmens_usuario a
            SET cd_reduzido_ativo = nCdReduzido2
            WHERE EXISTS ( SELECT 1
                            FROM dbaps.mens_usuario b
                            WHERE cd_mens_contrato = rMensContrato.CD_MENS_CONTRATO
                              AND b.cd_mens_usuario = a.cd_mens_usuario  );

          UPDATE dbaps.itmens_contrato a
            SET cd_reduzido_ativo = nCdReduzido2
            WHERE cd_mens_contrato = rMensContrato.CD_MENS_CONTRATO;

          FOR rVCMF IN ( SELECT TP_CONTA,
                                CD_CONTA_MEDICA,
                                CD_LANCAMENTO,
                                VL_TOTAL_TAXA_COBRADO_PTU,
                                VL_TOTAL_COBRADO,
                                QT_PAGO
                            FROM DBAPS.V_CTAS_MEDICAS_FATURA VCMF,
                                DBAPS.PRESTADOR P,
                                DBAPS.PROCEDIMENTO PR
                            WHERE VCMF.CD_MENS_CONTRATO = rMensContrato.CD_MENS_CONTRATO
                              AND VCMF.CD_PRESTADOR = P.CD_PRESTADOR
                              AND VCMF.CD_PROCEDIMENTO = PR.CD_PROCEDIMENTO(+)
                              AND P.TP_CREDENCIAMENTO = rCfg.TP_CREDENCIAMENTO
                              AND Nvl( pr.cd_item_despesa, 0 ) = rCfg.CD_ITEM_DESPESA ) LOOP

            IF rVCMF.TP_CONTA = 'A' THEN
              UPDATE DBAPS.ITREMESSA_PRESTADOR_FATURA
                SET CD_REDUZIDO_CE = nCdReduzido,
                    CD_REDUZIDO_CC = nCdReduzido3,
                    CD_REDUZIDO_FA = nCdReduzido4,
                    CD_REDUZIDO_ATIVO = nCdReduzido2,
                    CD_REDUZIDO_ACP = nCdReduzidoAtoPrincipal,
                    CD_REDUZIDO_ACA = nCdReduzidoAtoAuxiliar,
                    CD_REDUZIDO_ANC = nCdReduzidoAtoNaoCoop,
                    CD_ITEM_RES_FATURA = nCdItemRes,
                    CD_SETOR_FATURA = nCdSetor,
                    VL_ATO_PRINCIPAL = Trunc( VL_UNIT_COBRADO * ( nVlPercAP / 100 ), 2 ) + ( VL_UNIT_COBRADO - (Trunc( VL_UNIT_COBRADO * ( nVlPercAP / 100 ), 2 ) +
                                       Trunc( VL_UNIT_COBRADO * ( nVlPercAA / 100 ), 2 ) +
                                       Trunc( VL_UNIT_COBRADO * ( nVlPercNC / 100 ), 2 ) ) ),
                    VL_ATO_AUXILIAR = Trunc( VL_UNIT_COBRADO * ( nVlPercAA / 100 ), 2 ),
                    VL_ATO_NAO_COOP = Trunc( VL_UNIT_COBRADO * ( nVlPercNC / 100 ), 2 ),
                    CD_REDUZIDO_CE_TX_ADM = nCdReduzidoReceitaTxAdm,
                    CD_REDUZIDO_CC_TX_ADM = nCdReduzidoCancTxAdm,
                    CD_REDUZIDO_FA_TX_ADM = nCdReduzidoFATxAdm,
                    CD_REDUZIDO_ATIVO_TX_ADM = nCdReduzidoAtivoTxAdm,
                    CD_REDUZIDO_ACP_TX_ADM = nCdReduzidoACP,
                    CD_REDUZIDO_ACA_TX_ADM = nCdReduzidoACA,
                    CD_REDUZIDO_ANC_TX_ADM = nCdReduzidoANC,
                    CD_ITEM_RES_TX_ADM = nCdItemResTxAdm,
                    CD_SETOR_TX_ADM = nCdSetorTxAdm,
                    VL_ATO_PRINCIPAL_TX_ADM = Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercAP / 100 ), 2 ) + ( ( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO  * (Vl_Unit_Taxa_Cobrado / 100)), 2 ) -
                            ( Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercAP / 100 ), 2 ) ) -
                            ( Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO* (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercAA / 100 ), 2 ) ) -
                            ( Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO* (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercNC / 100 ), 2 ) )) ),
                    VL_ATO_AUXILIAR_TX_ADM = Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2) * ( nVlPercAA / 100 ), 2 ),
                    VL_ATO_NAO_COOP_TX_ADM = Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2) * ( nVlPercNC / 100 ), 2 )
                  WHERE CD_REMESSA = rVCMF.CD_cONTA_MEDICA
                    AND CD_LANCAMENTO = rVCMF.CD_LANCAMENTO
                    AND CD_MENS_CONTRATO = rMensContrato.CD_MENS_CONTRATO
                    AND EXISTS ( SELECT 1
                                   FROM dbaps.prestador p
                                   WHERE itremessa_prestador_fatura.cd_prestador = p.cd_prestador
                                   AND p.tp_credenciamento = rCfg.TP_CREDENCIAMENTO ) ;
            ELSE
              UPDATE DBAPS.ITCONTA_HOSPITALAR_FATURA
                SET CD_REDUZIDO_CE = nCdReduzido,
                    CD_REDUZIDO_CC = nCdReduzido3,
                    CD_REDUZIDO_FA = nCdReduzido4,
                    CD_REDUZIDO_ATIVO = nCdReduzido2,
                    CD_REDUZIDO_ACP = nCdReduzidoAtoPrincipal,
                    CD_REDUZIDO_ACA = nCdReduzidoAtoAuxiliar,
                    CD_REDUZIDO_ANC = nCdReduzidoAtoNaoCoop,
                    CD_ITEM_RES_FATURA = nCdItemRes,
                    CD_SETOR_FATURA = nCdSetor,
                    VL_ATO_PRINCIPAL = Trunc( VL_UNIT_COBRADO * ( nVlPercAP / 100 ), 2 ) + ( VL_UNIT_COBRADO - (Trunc( VL_UNIT_COBRADO * ( nVlPercAP / 100 ), 2 ) +
                                       Trunc( VL_UNIT_COBRADO * ( nVlPercAA / 100 ), 2 ) +
                                       Trunc( VL_UNIT_COBRADO * ( nVlPercNC / 100 ), 2 ) ) ),
                    VL_ATO_AUXILIAR = Trunc( VL_UNIT_COBRADO * ( nVlPercAA / 100 ), 2 ),
                    VL_ATO_NAO_COOP = Trunc( VL_UNIT_COBRADO * ( nVlPercNC / 100 ), 2 ),
                    CD_REDUZIDO_CE_TX_ADM = nCdReduzidoReceitaTxAdm,
                    CD_REDUZIDO_CC_TX_ADM = nCdReduzidoCancTxAdm,
                    CD_REDUZIDO_FA_TX_ADM = nCdReduzidoFATxAdm,
                    CD_REDUZIDO_ATIVO_TX_ADM = nCdReduzidoAtivoTxAdm,
                    CD_REDUZIDO_ACP_TX_ADM = nCdReduzidoACP,
                    CD_REDUZIDO_ACA_TX_ADM = nCdReduzidoACA,
                    CD_REDUZIDO_ANC_TX_ADM = nCdReduzidoANC,
                    CD_ITEM_RES_TX_ADM = nCdItemResTxAdm,
                    CD_SETOR_TX_ADM = nCdSetorTxAdm,
                    VL_ATO_PRINCIPAL_TX_ADM = Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercAP / 100 ), 2 ) + ( ( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO  * (Vl_Unit_Taxa_Cobrado / 100)), 2 ) -
                            ( Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercAP / 100 ), 2 ) ) -
                            ( Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO* (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercAA / 100 ), 2 ) ) -
                            ( Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO* (Vl_Unit_Taxa_Cobrado / 100)), 2 ) * ( nVlPercNC / 100 ), 2 ) )) ),
                    VL_ATO_AUXILIAR_TX_ADM = Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2) * ( nVlPercAA / 100 ), 2 ),
                    VL_ATO_NAO_COOP_TX_ADM = Trunc( Trunc( (VL_UNIT_COBRADO * rVCMF.QT_PAGO * (Vl_Unit_Taxa_Cobrado / 100)), 2) * ( nVlPercNC / 100 ), 2 )
                  WHERE CD_CONTA_HOSPITALAR = rVCMF.CD_cONTA_MEDICA
                    AND CD_LANCAMENTO = rVCMF.CD_LANCAMENTO
                    AND CD_MENS_CONTRATO = rMensContrato.CD_MENS_CONTRATO
                    AND EXISTS ( SELECT 1
                                   FROM dbaps.prestador p
                                   WHERE itconta_hospitalar_fatura.cd_prestador = p.cd_prestador
                                   AND p.tp_credenciamento = rCfg.TP_CREDENCIAMENTO ) ;
            END IF;
          END LOOP;
        END LOOP;
      END IF;

    END LOOP;

  END IF;

  IF PSN_DESPESA = 'S' THEN

    DECLARE
      nI NUMBER;

	    TYPE T_CFG_CTB_DESP IS RECORD(
		    CD_PLANO DBAPS.MVSAUDE_FCCT_DESPESA.CD_PLANO%TYPE,
        CD_ITEM_DESPESA DBAPS.MVSAUDE_FCCT_DESPESA.CD_ITEM_DESPESA%TYPE,
        TP_CREDENCIAMENTO DBAPS.MVSAUDE_FCCT_DESPESA.TP_CREDENCIAMENTO%TYPE,
        TP_ATO DBAPS.MVSAUDE_FCCT_DESPESA.TP_ATO%TYPE,
        TP_PROCEDIMENTO DBAPS.MVSAUDE_FCCT_DESPESA.TP_PROCEDIMENTO%TYPE,
        CD_REDUZIDO_EVENTO_CONHECIDO DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_EVENTO_CONHECIDO%TYPE,
        CD_ITEM_RES DBAPS.MVSAUDE_FCCT_DESPESA.CD_ITEM_RES%TYPE,
        CD_SETOR DBAPS.MVSAUDE_FCCT_DESPESA.CD_SETOR%TYPE,
        CD_REDUZIDO_RE DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_RE%TYPE,
        CD_REDUZIDO_CR DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR%TYPE,
        CD_REDUZIDO_CR_ASSUMIDA_ACA DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR_ASSUMIDA_ACA%TYPE,
        CD_REDUZIDO_CR_ASSUMIDA_ACP DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR_ASSUMIDA_ACP%TYPE,
        CD_REDUZIDO_CR_ASSUMIDA_ANC DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR_ASSUMIDA_ANC%TYPE,
        CD_REDUZIDO_CR_AVISO_ACA DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR_AVISO_ACA%TYPE,
        CD_REDUZIDO_CR_AVISO_ACP DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR_AVISO_ACP%TYPE,
        CD_REDUZIDO_CR_AVISO_ANC DBAPS.MVSAUDE_FCCT_DESPESA.CD_REDUZIDO_CR_AVISO_ANC%TYPE );

	    TYPE ACFG_CTB_DESP IS TABLE OF T_CFG_CTB_DESP INDEX BY BINARY_INTEGER;

	    VCFG_CTB_DESP ACFG_CTB_DESP;
	    VCFG_CTB_DESP_SP ACFG_CTB_DESP;

	    VCFG_CTB_DESP_GP ACFG_CTB_DESP;
	    VCFG_CTB_DESP_SP_GP ACFG_CTB_DESP;

      nIndex NUMBER;

      bLocated BOOLEAN;

      CURSOR cMFDComPlano ( PCD_PLANO NUMBER,
                            PCD_ITEM_DESPESA NUMBER,
                            PTP_CREDENCIAMENTO VARCHAR2,
                            PDT_VIGENCIA IN DATE,
                            PTP_PROCEDIMENTO IN VARCHAR2 ) IS
        SELECT cd_reduzido_evento_conhecido,
               cd_item_res,
               cd_setor,
               cd_reduzido_re,
               cd_reduzido_cr,
               cd_reduzido_cr_assumida_aca,
               cd_reduzido_cr_assumida_acp,
               cd_reduzido_cr_assumida_anc,
               cd_reduzido_cr_aviso_aca,
               cd_reduzido_cr_aviso_acp,
               cd_reduzido_cr_aviso_anc
          FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD
          WHERE MFD.CD_PLANO = Nvl( PCD_PLANO, -1 )
            AND MFD.CD_ITEM_DESPESA = PCD_ITEM_DESPESA
            AND MFD.TP_CREDENCIAMENTO = PTP_CREDENCIAMENTO
            AND MFD.TP_ATO = '0'
            AND MFD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
            AND MFD.TP_PROCEDIMENTO = PTP_PROCEDIMENTO
            AND MFD.DT_VIGENCIA = ( SELECT Max( MFD2.DT_VIGENCIA)
                                      FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD2
                                      WHERE MFD2.CD_PLANO = MFD.CD_PLANO
                                        AND MFD2.CD_ITEM_DESPESA = MFD.CD_ITEM_DESPESA
                                        AND MFD2.TP_CREDENCIAMENTO = MFD.TP_CREDENCIAMENTO
                                        AND MFD2.TP_ATO = MFD.TP_ATO
                                        AND MFD2.TP_PROCEDIMENTO = MFD.TP_PROCEDIMENTO
                                        AND MFD2.CD_MULTI_EMPRESA = MFD.CD_MULTI_EMPRESA
                                        AND MFD2.DT_VIGENCIA <= PDT_VIGENCIA );

      CURSOR cMFDSemPlano ( PCD_ITEM_DESPESA NUMBER,
                            PTP_CREDENCIAMENTO VARCHAR2,
                            PDT_VIGENCIA IN DATE,
                            PTP_PROCEDIMENTO IN VARCHAR2  ) IS
        SELECT cd_reduzido_evento_conhecido,
               cd_item_res,
               cd_setor,
               cd_reduzido_re,
               cd_reduzido_cr,
               cd_reduzido_cr_assumida_aca,
               cd_reduzido_cr_assumida_acp,
               cd_reduzido_cr_assumida_anc,
               cd_reduzido_cr_aviso_aca,
               cd_reduzido_cr_aviso_acp,
               cd_reduzido_cr_aviso_anc
          FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD
          WHERE MFD.CD_PLANO IS NULL
            AND MFD.CD_ITEM_DESPESA = PCD_ITEM_DESPESA
            AND MFD.TP_CREDENCIAMENTO = PTP_CREDENCIAMENTO
            AND MFD.TP_ATO = '0'
            AND MFD.TP_PROCEDIMENTO = PTP_PROCEDIMENTO
            AND MFD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
            AND MFD.DT_VIGENCIA = ( SELECT Max( MFD2.DT_VIGENCIA)
                                      FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD2
                                      WHERE MFD2.CD_PLANO IS NULL
                                        AND MFD2.CD_ITEM_DESPESA = MFD.CD_ITEM_DESPESA
                                        AND MFD2.TP_CREDENCIAMENTO = MFD.TP_CREDENCIAMENTO
                                        AND MFD2.TP_ATO = MFD.TP_ATO
                                        AND MFD2.TP_PROCEDIMENTO = MFD.TP_PROCEDIMENTO
                                        AND MFD2.CD_MULTI_EMPRESA = MFD.CD_MULTI_EMPRESA
                                        AND MFD2.DT_VIGENCIA <= PDT_VIGENCIA );

      cTpCredenciamento VARCHAR2(200);
      cSnUnimed VARCHAR2(200) := NULL;
      cTpCred VARCHAR2(200) := NULL;
      cTpContratualizacao VARCHAR2(200) := NULL;
      cTpProcedimento VARCHAR2(2000) := NULL;

      nCdReduzidoEC NUMBER;
      nCdItemRes NUMBER;
      nCdSetor NUMBER;
      nCdReduzidoRE NUMBER;
      nCdReduzidoCR NUMBER;
      nCdPlano NUMBER := NULL;
      nCdItemDespesa NUMBER := NULL;
      nContador NUMBER := 0;
      nCdItemDspIntern NUMBER;

      nCdReduzidoCRAssumidaACA NUMBER;
      nCdReduzidoCRAssumidaACP NUMBER;
      nCdReduzidoCRAssumidaANC NUMBER;
      nCdReduzidoCRAvisoACA NUMBER;
      nCdReduzidoCRAvisoACP NUMBER;
      nCdReduzidoCRAvisoANC NUMBER;

      bTpProcedimento BOOLEAN;

      cCfgCooperado VARCHAR2(2000);

    BEGIN
      SELECT To_Date( To_Char( To_Date(PNR_MESANO_INICIAL, 'YYYYMM'), 'dd/mm/yyyy'), 'dd/mm/yyyy'),
            Last_Day( To_Date( To_Char( To_Date(PNR_MESANO_FINAL, 'YYYYMM'), 'dd/mm/yyyy') || '23:59:59', 'dd/mm/yyyy hh24:mi:ss') )
        INTO dDataInicial, dDataFinal
        FROM DUAL;

      cCfgCooperado := 'P';

      BEGIN
        SELECT DISTINCT TP_CREDENCIAMENTO
          INTO cCfgCooperado
          FROM DBAPS.MVSAUDE_FCCT_DESPESA
          WHERE TP_CREDENCIAMENTO = 'D';
      EXCEPTION
        WHEN OTHERS THEN
          cCfgCooperado := 'P';
      END;

      --***************************************************
      --* Classificando os lançamentos de horas trabalhadas
      --* pendentes de classificação contabil
      --***************************************************
      BEGIN
        FOR r IN ( SELECT ilh.cd_itlancamento_hora,  Nvl( ilh.cd_reduzido_ctb, idsh.cd_reduzido ) cd_reduzido_ctb, ilh.cd_setor
                    FROM dbaps.itlancamento_hora ilh,
                          dbaps.item_despesa_setor_hora idsh,
                          dbaps.v_credito_debito_linear pcd
                    WHERE ilh.cd_setor = idsh.cd_setor
                      AND ilh.cd_itlancamento_hora = pcd.cd_itlancamento_hora
                      AND ( ilh.cd_reduzido_ctb IS NOT NULL OR idsh.cd_reduzido IS NOT NULL )
                      AND pcd.cd_item_despesa = idsh.cd_item_despesa
                      AND ( pcd.cd_reduzido_ec IS NULL OR pcd.cd_setor IS NULL )
                      AND pcd.cd_multi_empresa = PCD_MULTI_EMPRESA
                      AND pcd.dt_competencia between PNR_MESANO_INICIAL AND PNR_MESANO_FINAL ) LOOP

          UPDATE DBAPS.PRESTADOR_CREDITO_DEBITO
            SET CD_REDUZIDO_EC = R.CD_REDUZIDO_CTB
               ,CD_SETOR = R.CD_SETOR
            WHERE CD_ITLANCAMENTO_HORA = R.CD_ITLANCAMENTO_HORA
              AND CD_REDUZIDO_EC IS NULL;
        END LOOP;

      END;

      BEGIN
        SELECT cd_item_despesa
          INTO nCdItemDspIntern
          FROM dbaps.item_despesa
          WHERE tp_origem_dados = 'I'
            AND ROWNUM = 1;
      EXCEPTION
        WHEN OTHERS THEN
          nCdItemDspIntern := NULL;
      END;

      --***************************************************
      --* Classificando os lançamentos de reembolsos
      --***************************************************
      FOR rRE IN ( SELECT IR.CD_ITREEMBOLSO,
                          IR.CD_REDUZIDO_EC,
                          IR.CD_SETOR,
                          IR.CD_ITEM_RES,
                          R.TP_REEMBOLSO,
                          US.CD_PLANO,
                          PR.CD_ITEM_DESPESA
                     FROM DBAPS.REEMBOLSO R,
                          DBAPS.ITREEMBOLSO IR,
                          DBAPS.USUARIO US,
                          DBAPS.PROCEDIMENTO PR
                     WHERE R.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
                       AND R.CD_REEMBOLSO = IR.CD_REEMBOLSO
                       AND R.DT_CONTABILIZACAO BETWEEN dDataInicial AND dDataFinal
                       AND R.TP_REEMBOLSO IN ( 'A', 'R' )
                       AND R.CD_MATRICULA = US.CD_MATRICULA(+)
                       AND IR.CD_PROCEDIMENTO = PR.CD_PROCEDIMENTO(+) ) LOOP

        IF rRE.tp_reembolso = 'A' THEN
          cTpCredenciamento := 'O';
        ELSE
          cTpCredenciamento := 'RS';
        END IF;

        nCdReduzidoEC := NULL;
        nCdItemRes := NULL;
        nCdSetor := NULL;
        nCdReduzidoRE := NULL;
        nCdReduzidoCR := NULL;

        nCdReduzidoCRAssumidaACA := NULL;
        nCdReduzidoCRAssumidaACP := NULL;
        nCdReduzidoCRAssumidaANC := NULL;
        nCdReduzidoCRAvisoACA := NULL;
        nCdReduzidoCRAvisoACP := NULL;
        nCdReduzidoCRAvisoANC := NULL;

        IF rRE.CD_PLANO IS NOT NULL THEN
          OPEN  cMFDComPlano ( rRE.CD_PLANO, rRE.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
          FETCH cMFDComPlano INTO nCdReduzidoEC,
                                  nCdItemRes,
                                  nCdSetor,
                                  nCdReduzidoRE,
                                  nCdReduzidoCR,
                                  nCdReduzidoCRAssumidaACA,
                                  nCdReduzidoCRAssumidaACP,
                                  nCdReduzidoCRAssumidaANC,
                                  nCdReduzidoCRAvisoACA,
                                  nCdReduzidoCRAvisoACP,
                                  nCdReduzidoCRAvisoANC;

          IF cMFDComPlano%NOTFOUND THEN
            CLOSE cMFDComPlano;
            OPEN  cMFDSemPlano ( rRE.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
            FETCH cMFDSemPlano INTO nCdReduzidoEC,
                                    nCdItemRes,
                                    nCdSetor,
                                    nCdReduzidoRE,
                                    nCdReduzidoCR,
                                    nCdReduzidoCRAssumidaACA,
                                    nCdReduzidoCRAssumidaACP,
                                    nCdReduzidoCRAssumidaANC,
                                    nCdReduzidoCRAvisoACA,
                                    nCdReduzidoCRAvisoACP,
                                    nCdReduzidoCRAvisoANC;
            CLOSE cMFDSemPlano;
          ELSE
            CLOSE cMFDComPlano;
          END IF;
        ELSE
          OPEN  cMFDSemPlano ( rRE.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
          FETCH cMFDSemPlano INTO nCdReduzidoEC,
                                  nCdItemRes,
                                  nCdSetor,
                                  nCdReduzidoRE,
                                  nCdReduzidoCR,
                                  nCdReduzidoCRAssumidaACA,
                                  nCdReduzidoCRAssumidaACP,
                                  nCdReduzidoCRAssumidaANC,
                                  nCdReduzidoCRAvisoACA,
                                  nCdReduzidoCRAvisoACP,
                                  nCdReduzidoCRAvisoANC;

          CLOSE cMFDSemPlano;
        END IF;

        IF nCdReduzidoEC IS NOT NULL OR ( nCdReduzidoEC <> rRE.CD_REDUZIDO_EC OR nCdSetor <> rRE.CD_SETOR OR nCdItemRes <> rRE.CD_ITEM_RES ) THEN
          UPDATE DBAPS.ITREEMBOLSO IRE
            SET CD_REDUZIDO_EC = nCdReduzidoEC
               ,CD_REDUZIDO_CR = nCdReduzidoCR
               ,CD_REDUZIDO_RE = nCdReduzidoRE
               ,CD_SETOR = nCdSetor
               ,CD_ITEM_RES = nCdItemRes
            WHERE CD_ITREEMBOLSO = rRE.CD_ITREEMBOLSO;
        END IF;

      END LOOP;

      --***************************************************
      --* Classificando os lançamentos de credito/débito
      --* linear
      --***************************************************
      FOR rCD IN ( SELECT Nvl( US.CD_PLANO, VCD.CD_PLANO ) CD_PLANO,
                          VCD.CD_PRES_CR_DB,
                          VCD.CD_ITEM_DESPESA,
                          Decode( PR.TP_CREDENCIAMENTO, 'D', cCfgCooperado, PR.TP_CREDENCIAMENTO ) TP_CREDENCIAMENTO,
                          DECODE( PU.CD_PRESTADOR, NULL, 'N', 'S' ) SN_UNIMED,
                          NVL( PR.TP_CONTRATUALIZACAO, 'D') TP_CONTRATUALIZACAO
                     FROM DBAPS.V_CREDITO_DEBITO_LINEAR VCD,
                          DBAPS.PRESTADOR PR,
                          DBAPS.PTU_UNIMED PU,
                          DBAPS.USUARIO US
                     WHERE VCD.DT_APRESENTACAO BETWEEN dDataInicial AND dDataFinal
                       AND VCD.CD_ITLANCAMENTO_HORA IS NULL
                       AND VCD.CD_PRESTADOR = PR.CD_PRESTADOR
                       AND VCD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
                       AND VCD.CD_MATRICULA = US.CD_MATRICULA(+)
                       AND PR.CD_PRESTADOR = PU.CD_PRESTADOR(+) ) LOOP

        IF rCD.tp_contratualizacao = 'I' THEN
          cTpCredenciamento := 'RI';

        ELSIF rCD.sn_unimed = 'S' THEN
          cTpCredenciamento := 'IC';

        ELSE
          cTpCredenciamento := rCD.tp_credenciamento;

        END IF;

        nCdReduzidoEC := NULL;
        nCdItemRes := NULL;
        nCdSetor := NULL;
        nCdReduzidoRE := NULL;
        nCdReduzidoCR := NULL;

        nCdReduzidoCRAssumidaACA := NULL;
        nCdReduzidoCRAssumidaACP := NULL;
        nCdReduzidoCRAssumidaANC := NULL;
        nCdReduzidoCRAvisoACA := NULL;
        nCdReduzidoCRAvisoACP := NULL;
        nCdReduzidoCRAvisoANC := NULL;

        IF rCD.CD_PLANO IS NOT NULL THEN
          OPEN  cMFDComPlano ( rCD.CD_PLANO, rCD.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
          FETCH cMFDComPlano INTO nCdReduzidoEC,
                                  nCdItemRes,
                                  nCdSetor,
                                  nCdReduzidoRE,
                                  nCdReduzidoCR,
                                  nCdReduzidoCRAssumidaACA,
                                  nCdReduzidoCRAssumidaACP,
                                  nCdReduzidoCRAssumidaANC,
                                  nCdReduzidoCRAvisoACA,
                                  nCdReduzidoCRAvisoACP,
                                  nCdReduzidoCRAvisoANC;

          IF cMFDComPlano%NOTFOUND THEN
            CLOSE cMFDComPlano;

            OPEN  cMFDComPlano ( rCD.CD_PLANO, rCD.CD_ITEM_DESPESA, rCD.TP_CREDENCIAMENTO, dDataInicial, 'TD' );
            FETCH cMFDComPlano INTO nCdReduzidoEC,
                                    nCdItemRes,
                                    nCdSetor,
                                    nCdReduzidoRE,
                                    nCdReduzidoCR,
                                    nCdReduzidoCRAssumidaACA,
                                    nCdReduzidoCRAssumidaACP,
                                    nCdReduzidoCRAssumidaANC,
                                    nCdReduzidoCRAvisoACA,
                                    nCdReduzidoCRAvisoACP,
                                    nCdReduzidoCRAvisoANC;

            IF cMFDComPlano%NOTFOUND THEN
              OPEN  cMFDSemPlano ( rCD.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
              FETCH cMFDSemPlano INTO nCdReduzidoEC,
                                      nCdItemRes,
                                      nCdSetor,
                                      nCdReduzidoRE,
                                      nCdReduzidoCR,
                                      nCdReduzidoCRAssumidaACA,
                                      nCdReduzidoCRAssumidaACP,
                                      nCdReduzidoCRAssumidaANC,
                                      nCdReduzidoCRAvisoACA,
                                      nCdReduzidoCRAvisoACP,
                                      nCdReduzidoCRAvisoANC;

              IF cMFDSemPlano%NOTFOUND THEN
                CLOSE cMFDSemPlano;
                OPEN  cMFDSemPlano ( rCD.CD_ITEM_DESPESA, rCD.TP_CREDENCIAMENTO, dDataInicial, 'TD' );
                FETCH cMFDSemPlano INTO nCdReduzidoEC,
                                        nCdItemRes,
                                        nCdSetor,
                                        nCdReduzidoRE,
                                        nCdReduzidoCR,
                                        nCdReduzidoCRAssumidaACA,
                                        nCdReduzidoCRAssumidaACP,
                                        nCdReduzidoCRAssumidaANC,
                                        nCdReduzidoCRAvisoACA,
                                        nCdReduzidoCRAvisoACP,
                                        nCdReduzidoCRAvisoANC;

                CLOSE cMFDSemPlano;
              ELSE
                CLOSE cMFDSemPlano;
              END IF;

            END IF;

            CLOSE cMFDComPlano;

          ELSE
            CLOSE cMFDComPlano;

          END IF;

        ELSE
          OPEN  cMFDComPlano ( -1, rCD.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
          FETCH cMFDComPlano INTO nCdReduzidoEC,
                                  nCdItemRes,
                                  nCdSetor,
                                  nCdReduzidoRE,
                                  nCdReduzidoCR,
                                  nCdReduzidoCRAssumidaACA,
                                  nCdReduzidoCRAssumidaACP,
                                  nCdReduzidoCRAssumidaANC,
                                  nCdReduzidoCRAvisoACA,
                                  nCdReduzidoCRAvisoACP,
                                  nCdReduzidoCRAvisoANC;

          IF cMFDComPlano%NOTFOUND THEN
            OPEN  cMFDSemPlano ( rCD.CD_ITEM_DESPESA, cTpCredenciamento, dDataInicial, 'TD' );
            FETCH cMFDSemPlano INTO nCdReduzidoEC,
                                    nCdItemRes,
                                    nCdSetor,
                                    nCdReduzidoRE,
                                    nCdReduzidoCR,
                                    nCdReduzidoCRAssumidaACA,
                                    nCdReduzidoCRAssumidaACP,
                                    nCdReduzidoCRAssumidaANC,
                                    nCdReduzidoCRAvisoACA,
                                    nCdReduzidoCRAvisoACP,
                                    nCdReduzidoCRAvisoANC;

            IF cMFDSemPlano%NOTFOUND THEN
              CLOSE cMFDSemPlano;
              OPEN  cMFDSemPlano ( rCD.CD_ITEM_DESPESA, rCD.TP_CREDENCIAMENTO, dDataInicial, 'TD' );
              FETCH cMFDSemPlano INTO nCdReduzidoEC,
                                      nCdItemRes,
                                      nCdSetor,
                                      nCdReduzidoRE,
                                      nCdReduzidoCR,
                                      nCdReduzidoCRAssumidaACA,
                                      nCdReduzidoCRAssumidaACP,
                                      nCdReduzidoCRAssumidaANC,
                                      nCdReduzidoCRAvisoACA,
                                      nCdReduzidoCRAvisoACP,
                                      nCdReduzidoCRAvisoANC;
              CLOSE cMFDSemPlano;
            ELSE
              CLOSE cMFDSemPlano;
            END IF;
          END IF;

          CLOSE cMFDComPlano;
        END IF;

        IF nCdReduzidoEC IS NOT NULL OR nCdReduzidoRE IS NOT NULL THEN
          UPDATE DBAPS.PRESTADOR_CREDITO_DEBITO PCD
            SET CD_REDUZIDO_EC = Decode( PCD.TP_LANCAMENTO, 'D', nCdReduzidoRE, nCdReduzidoEC )
                ,CD_SETOR = nCdSetor
                ,CD_ITEM_RES = nCdItemRes
            WHERE CD_PRES_CR_DB = rCD.CD_PRES_CR_DB;
        END IF;

      END LOOP;


      --* POR GRUPO DE PROCEDIMENTO NAO
      nIndex := 0;

      VCFG_CTB_DESP.DELETE();
      FOR r IN ( SELECT cd_plano,
                        cd_item_despesa,
                        tp_credenciamento,
                        tp_ato,
                        tp_procedimento,
                        cd_reduzido_evento_conhecido,
                        cd_item_res,
                        cd_setor,
                        cd_reduzido_re,
                        cd_reduzido_cr,
                        cd_reduzido_cr_assumida_aca,
                        cd_reduzido_cr_assumida_acp,
                        cd_reduzido_cr_assumida_anc,
                        cd_reduzido_cr_aviso_aca,
                        cd_reduzido_cr_aviso_acp,
                        cd_reduzido_cr_aviso_anc
                    FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD
                    WHERE MFD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
                      AND MFD.CD_PLANO IS NOT NULL
                      AND MFD.TP_PROCEDIMENTO = 'TD'
                      AND MFD.DT_VIGENCIA = ( SELECT Max( MFD2.DT_VIGENCIA)
                                                FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD2
                                                WHERE MFD2.CD_PLANO = MFD.CD_PLANO
                                                  AND MFD2.CD_ITEM_DESPESA = MFD.CD_ITEM_DESPESA
                                                  AND MFD2.TP_CREDENCIAMENTO = MFD.TP_CREDENCIAMENTO
                                                  AND MFD2.TP_ATO = MFD.TP_ATO
                                                  AND MFD2.TP_PROCEDIMENTO = MFD.TP_PROCEDIMENTO
                                                  AND MFD2.CD_MULTI_EMPRESA = MFD.CD_MULTI_EMPRESA
                                                  AND MFD2.DT_VIGENCIA <= Trunc(SYSDATE) )
                    ORDER BY CD_PLANO, CD_ITEM_DESPESA, TP_CREDENCIAMENTO, TP_PROCEDIMENTO ) LOOP

        nIndex := nIndex + 1;

        VCFG_CTB_DESP(nIndex).CD_PLANO := r.CD_PLANO;
        VCFG_CTB_DESP(nIndex).CD_ITEM_DESPESA := r.CD_ITEM_DESPESA;
        VCFG_CTB_DESP(nIndex).TP_CREDENCIAMENTO := r.TP_CREDENCIAMENTO;
        VCFG_CTB_DESP(nIndex).TP_ATO := r.TP_ATO;
        VCFG_CTB_DESP(nIndex).TP_PROCEDIMENTO := r.TP_PROCEDIMENTO;
        VCFG_CTB_DESP(nIndex).CD_REDUZIDO_EVENTO_CONHECIDO := r.CD_REDUZIDO_EVENTO_CONHECIDO;
        VCFG_CTB_DESP(nIndex).CD_ITEM_RES := r.CD_ITEM_RES;
        VCFG_CTB_DESP(nIndex).CD_SETOR := r.CD_SETOR;
        VCFG_CTB_DESP(nIndex).CD_REDUZIDO_RE := r.CD_REDUZIDO_RE;
        VCFG_CTB_DESP(nIndex).CD_REDUZIDO_CR := r.CD_REDUZIDO_CR;

        VCFG_CTB_DESP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACA := R.CD_REDUZIDO_CR_ASSUMIDA_ACA;
        VCFG_CTB_DESP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACP := R.CD_REDUZIDO_CR_ASSUMIDA_ACP;
        VCFG_CTB_DESP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ANC := R.CD_REDUZIDO_CR_ASSUMIDA_ANC;
        VCFG_CTB_DESP(NINDEX).CD_REDUZIDO_CR_AVISO_ACA := R.CD_REDUZIDO_CR_AVISO_ACA;
        VCFG_CTB_DESP(NINDEX).CD_REDUZIDO_CR_AVISO_ACP := R.CD_REDUZIDO_CR_AVISO_ACP;
        VCFG_CTB_DESP(NINDEX).CD_REDUZIDO_CR_AVISO_ANC := R.CD_REDUZIDO_CR_AVISO_ANC;
      END LOOP;

      VCFG_CTB_DESP_SP.DELETE();
      nIndex := 0;
      FOR r IN ( SELECT cd_plano,
                        cd_item_despesa,
                        tp_credenciamento,
                        tp_ato,
                        tp_procedimento,
                        cd_reduzido_evento_conhecido,
                        cd_item_res,
                        cd_setor,
                        cd_reduzido_re,
                        cd_reduzido_cr,
                        cd_reduzido_cr_assumida_aca,
                        cd_reduzido_cr_assumida_acp,
                        cd_reduzido_cr_assumida_anc,
                        cd_reduzido_cr_aviso_aca,
                        cd_reduzido_cr_aviso_acp,
                        cd_reduzido_cr_aviso_anc
                    FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD
                    WHERE MFD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
                      AND MFD.CD_PLANO IS NULL
                      AND MFD.TP_PROCEDIMENTO = 'TD'
                      AND MFD.DT_VIGENCIA = ( SELECT Max( MFD2.DT_VIGENCIA)
                                                FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD2
                                                WHERE MFD2.CD_PLANO IS NULL
                                                  AND MFD2.CD_ITEM_DESPESA = MFD.CD_ITEM_DESPESA
                                                  AND MFD2.TP_CREDENCIAMENTO = MFD.TP_CREDENCIAMENTO
                                                  AND MFD2.TP_ATO = MFD.TP_ATO
                                                  AND MFD2.TP_PROCEDIMENTO = MFD.TP_PROCEDIMENTO
                                                  AND MFD2.CD_MULTI_EMPRESA = MFD.CD_MULTI_EMPRESA
                                                  AND MFD2.DT_VIGENCIA <= Trunc(SYSDATE) )
                    ORDER BY CD_PLANO, CD_ITEM_DESPESA, TP_CREDENCIAMENTO, TP_PROCEDIMENTO ) LOOP

        nIndex := nIndex + 1;

        VCFG_CTB_DESP_SP(nIndex).CD_PLANO := r.CD_PLANO;
        VCFG_CTB_DESP_SP(nIndex).CD_ITEM_DESPESA := r.CD_ITEM_DESPESA;
        VCFG_CTB_DESP_SP(nIndex).TP_CREDENCIAMENTO := r.TP_CREDENCIAMENTO;
        VCFG_CTB_DESP_SP(nIndex).TP_ATO := r.TP_ATO;
        VCFG_CTB_DESP_SP(nIndex).TP_PROCEDIMENTO := r.TP_PROCEDIMENTO;
        VCFG_CTB_DESP_SP(nIndex).CD_REDUZIDO_EVENTO_CONHECIDO := r.CD_REDUZIDO_EVENTO_CONHECIDO;
        VCFG_CTB_DESP_SP(nIndex).CD_ITEM_RES := r.CD_ITEM_RES;
        VCFG_CTB_DESP_SP(nIndex).CD_SETOR := r.CD_SETOR;
        VCFG_CTB_DESP_SP(nIndex).CD_REDUZIDO_RE := r.CD_REDUZIDO_RE;
        VCFG_CTB_DESP_SP(nIndex).CD_REDUZIDO_CR := r.CD_REDUZIDO_CR;

        VCFG_CTB_DESP_SP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACA := R.CD_REDUZIDO_CR_ASSUMIDA_ACA;
        VCFG_CTB_DESP_SP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACP := R.CD_REDUZIDO_CR_ASSUMIDA_ACP;
        VCFG_CTB_DESP_SP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ANC := R.CD_REDUZIDO_CR_ASSUMIDA_ANC;
        VCFG_CTB_DESP_SP(NINDEX).CD_REDUZIDO_CR_AVISO_ACA := R.CD_REDUZIDO_CR_AVISO_ACA;
        VCFG_CTB_DESP_SP(NINDEX).CD_REDUZIDO_CR_AVISO_ACP := R.CD_REDUZIDO_CR_AVISO_ACP;
        VCFG_CTB_DESP_SP(NINDEX).CD_REDUZIDO_CR_AVISO_ANC := R.CD_REDUZIDO_CR_AVISO_ANC;
      END LOOP;

      --* POR GRUPO DE PROCEDIMENTO SIM
      nIndex := 0;

      VCFG_CTB_DESP_GP.DELETE();
      FOR r IN ( SELECT cd_plano,
                        cd_item_despesa,
                        tp_credenciamento,
                        tp_ato,
                        tp_procedimento,
                        cd_reduzido_evento_conhecido,
                        cd_item_res,
                        cd_setor,
                        cd_reduzido_re,
                        cd_reduzido_cr,
                        cd_reduzido_cr_assumida_aca,
                        cd_reduzido_cr_assumida_acp,
                        cd_reduzido_cr_assumida_anc,
                        cd_reduzido_cr_aviso_aca,
                        cd_reduzido_cr_aviso_acp,
                        cd_reduzido_cr_aviso_anc
                    FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD
                    WHERE MFD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
                      AND MFD.CD_PLANO IS NOT NULL
                      AND MFD.TP_PROCEDIMENTO <> 'TD'
                      AND MFD.DT_VIGENCIA = ( SELECT Max( MFD2.DT_VIGENCIA)
                                                FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD2
                                                WHERE MFD2.CD_PLANO = MFD.CD_PLANO
                                                  AND MFD2.CD_ITEM_DESPESA = MFD.CD_ITEM_DESPESA
                                                  AND MFD2.TP_CREDENCIAMENTO = MFD.TP_CREDENCIAMENTO
                                                  AND MFD2.TP_ATO = MFD.TP_ATO
                                                  AND MFD2.TP_PROCEDIMENTO = MFD.TP_PROCEDIMENTO
                                                  AND MFD2.CD_MULTI_EMPRESA = MFD.CD_MULTI_EMPRESA
                                                  AND MFD2.DT_VIGENCIA <= Trunc(SYSDATE) )
                    ORDER BY CD_PLANO, CD_ITEM_DESPESA, TP_CREDENCIAMENTO, TP_PROCEDIMENTO ) LOOP

        nIndex := nIndex + 1;

        VCFG_CTB_DESP_GP(nIndex).CD_PLANO := r.CD_PLANO;
        VCFG_CTB_DESP_GP(nIndex).CD_ITEM_DESPESA := r.CD_ITEM_DESPESA;
        VCFG_CTB_DESP_GP(nIndex).TP_CREDENCIAMENTO := r.TP_CREDENCIAMENTO;
        VCFG_CTB_DESP_GP(nIndex).TP_ATO := r.TP_ATO;
        VCFG_CTB_DESP_GP(nIndex).TP_PROCEDIMENTO := r.TP_PROCEDIMENTO;
        VCFG_CTB_DESP_GP(nIndex).CD_REDUZIDO_EVENTO_CONHECIDO := r.CD_REDUZIDO_EVENTO_CONHECIDO;
        VCFG_CTB_DESP_GP(nIndex).CD_ITEM_RES := r.CD_ITEM_RES;
        VCFG_CTB_DESP_GP(nIndex).CD_SETOR := r.CD_SETOR;
        VCFG_CTB_DESP_GP(nIndex).CD_REDUZIDO_RE := r.CD_REDUZIDO_RE;
        VCFG_CTB_DESP_GP(nIndex).CD_REDUZIDO_CR := r.CD_REDUZIDO_CR;

        VCFG_CTB_DESP_GP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACA := R.CD_REDUZIDO_CR_ASSUMIDA_ACA;
        VCFG_CTB_DESP_GP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACP := R.CD_REDUZIDO_CR_ASSUMIDA_ACP;
        VCFG_CTB_DESP_GP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ANC := R.CD_REDUZIDO_CR_ASSUMIDA_ANC;
        VCFG_CTB_DESP_GP(NINDEX).CD_REDUZIDO_CR_AVISO_ACA := R.CD_REDUZIDO_CR_AVISO_ACA;
        VCFG_CTB_DESP_GP(NINDEX).CD_REDUZIDO_CR_AVISO_ACP := R.CD_REDUZIDO_CR_AVISO_ACP;
        VCFG_CTB_DESP_GP(NINDEX).CD_REDUZIDO_CR_AVISO_ANC := R.CD_REDUZIDO_CR_AVISO_ANC;
      END LOOP;

      VCFG_CTB_DESP_SP_GP.DELETE();
      nIndex := 0;
      FOR r IN ( SELECT cd_plano,
                        cd_item_despesa,
                        tp_credenciamento,
                        tp_ato,
                        tp_procedimento,
                        cd_reduzido_evento_conhecido,
                        cd_item_res,
                        cd_setor,
                        cd_reduzido_re,
                        cd_reduzido_cr,
                        cd_reduzido_cr_assumida_aca,
                        cd_reduzido_cr_assumida_acp,
                        cd_reduzido_cr_assumida_anc,
                        cd_reduzido_cr_aviso_aca,
                        cd_reduzido_cr_aviso_acp,
                        cd_reduzido_cr_aviso_anc
                    FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD
                    WHERE MFD.CD_MULTI_EMPRESA = PCD_MULTI_EMPRESA
                      AND MFD.CD_PLANO IS NULL
                      AND MFD.TP_PROCEDIMENTO <> 'TD'
                      AND MFD.DT_VIGENCIA = ( SELECT Max( MFD2.DT_VIGENCIA)
                                                FROM DBAPS.MVSAUDE_FCCT_DESPESA MFD2
                                                WHERE MFD2.CD_PLANO IS NULL
                                                  AND MFD2.CD_ITEM_DESPESA = MFD.CD_ITEM_DESPESA
                                                  AND MFD2.TP_CREDENCIAMENTO = MFD.TP_CREDENCIAMENTO
                                                  AND MFD2.TP_ATO = MFD.TP_ATO
                                                  AND MFD2.TP_PROCEDIMENTO = MFD.TP_PROCEDIMENTO
                                                  AND MFD2.CD_MULTI_EMPRESA = MFD.CD_MULTI_EMPRESA
                                                  AND MFD2.DT_VIGENCIA <= Trunc(SYSDATE) )
                    ORDER BY CD_PLANO, CD_ITEM_DESPESA, TP_CREDENCIAMENTO, TP_PROCEDIMENTO ) LOOP

        nIndex := nIndex + 1;

        VCFG_CTB_DESP_SP_GP(nIndex).CD_PLANO := r.CD_PLANO;
        VCFG_CTB_DESP_SP_GP(nIndex).CD_ITEM_DESPESA := r.CD_ITEM_DESPESA;
        VCFG_CTB_DESP_SP_GP(nIndex).TP_CREDENCIAMENTO := r.TP_CREDENCIAMENTO;
        VCFG_CTB_DESP_SP_GP(nIndex).TP_ATO := r.TP_ATO;
        VCFG_CTB_DESP_SP_GP(nIndex).TP_PROCEDIMENTO := r.TP_PROCEDIMENTO;
        VCFG_CTB_DESP_SP_GP(nIndex).CD_REDUZIDO_EVENTO_CONHECIDO := r.CD_REDUZIDO_EVENTO_CONHECIDO;
        VCFG_CTB_DESP_SP_GP(nIndex).CD_ITEM_RES := r.CD_ITEM_RES;
        VCFG_CTB_DESP_SP_GP(nIndex).CD_SETOR := r.CD_SETOR;
        VCFG_CTB_DESP_SP_GP(nIndex).CD_REDUZIDO_RE := r.CD_REDUZIDO_RE;
        VCFG_CTB_DESP_SP_GP(nIndex).CD_REDUZIDO_CR := r.CD_REDUZIDO_CR;

        VCFG_CTB_DESP_SP_GP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACA := R.CD_REDUZIDO_CR_ASSUMIDA_ACA;
        VCFG_CTB_DESP_SP_GP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ACP := R.CD_REDUZIDO_CR_ASSUMIDA_ACP;
        VCFG_CTB_DESP_SP_GP(NINDEX).CD_REDUZIDO_CR_ASSUMIDA_ANC := R.CD_REDUZIDO_CR_ASSUMIDA_ANC;
        VCFG_CTB_DESP_SP_GP(NINDEX).CD_REDUZIDO_CR_AVISO_ACA := R.CD_REDUZIDO_CR_AVISO_ACA;
        VCFG_CTB_DESP_SP_GP(NINDEX).CD_REDUZIDO_CR_AVISO_ACP := R.CD_REDUZIDO_CR_AVISO_ACP;
        VCFG_CTB_DESP_SP_GP(NINDEX).CD_REDUZIDO_CR_AVISO_ANC := R.CD_REDUZIDO_CR_AVISO_ANC;
      END LOOP;

      FOR rVCM IN ( SELECT DISTINCT Decode( Nvl( pu.cd_prestador, pu_exe.cd_prestador ), NULL, 'N', 'S' ) sn_unimed,
                           vcm.cd_tipo_atendimento_intermed,
                           vcm.tp_conta,
                           vcm.cd_conta_medica,
                           vcm.cd_lancamento_filho,
                           vcm.tp_item,
                           vcm.cd_reduzido_ec,
                           vcm.cd_reduzido_re,
                           vcm.cd_reduzido_cr,
                           vcm.cd_setor,
                           vcm.cd_item_res,
                           vcm.sn_contabiliza_franquia,
                           Nvl( us.cd_plano, -1 ) cd_plano,
                           Decode( vcm.tp_conta, 'I', NULL, pro.cd_item_despesa ) cd_item_despesa,

                           CASE
                             WHEN Nvl( Nvl( pr.sn_captation, pr_exe.sn_captation ), 'N') = 'S' AND ft.sn_nao_aplicar_captation = 'S' THEN
                               'CP'
                             ELSE
                               Decode( Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ), 'D', cCfgCooperado, 'I', 'C', Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ) )
                           END tp_credenciamento,

--                           Decode( Nvl( Nvl( pr.sn_captation, pr_exe.sn_captation ), 'N'), 'S', 'CP', Decode( Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ), 'D', cCfgCooperado, 'I', 'C', Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ) ) ) tp_credenciamento,
                           Nvl( Nvl( pr.tp_contratualizacao, pr_exe.tp_contratualizacao ), 'D') tp_contratualizacao,
                           pro.tp_natureza,
                           gp.tp_gru_pro,
                           vcm.tp_beneficiario,
                           vcm.rowid_conta,
                           vcm.rowid_itconta,
                           vcm.rowid_equipe,
                           vcm.cd_lancamento_equipe
                      FROM dbaps.v_ctas_medicas vcm
                          ,dbaps.prestador pr
                          ,dbaps.prestador pr_exe
                          ,dbaps.procedimento pro
                          ,dbaps.usuario us
                          ,dbaps.ptu_unimed pu
                          ,dbaps.ptu_unimed pu_exe
                          ,dbaps.grupo_procedimento gp
                          ,dbaps.fatura ft
                      WHERE vcm.dt_apresentacao BETWEEN dDataInicial AND dDataFinal
                        AND vcm.cd_prestador_pagamento = pr.cd_prestador(+)
                        AND vcm.cd_procedimento_principal = pro.cd_procedimento--(+)
                        AND vcm.cd_prestador = pr_exe.cd_prestador(+)
                        AND vcm.cd_matricula = us.cd_matricula(+)
                        AND vcm.cd_multi_empresa = pcd_multi_empresa
                        AND vcm.tp_fatura <> 'R'
                        AND vcm.cd_fatura = ft.cd_fatura
                        AND pr.cd_prestador = pu.cd_prestador(+)
                        AND pr_exe.cd_prestador = pu_exe.cd_prestador(+)
                        AND pro.cd_grupo_procedimento = gp.cd_grupo_procedimento
--                      AND ( VCM.CD_REDUZIDO_EC IS NULL OR vcm.CD_SETOR IS NULL OR ( Nvl( VCM.VL_TOTAL_GLOSADO, 0 ) <> 0 AND VCM.CD_REDUZIDO_RE IS NULL ) )
                      GROUP BY Decode( Nvl( pu.cd_prestador, pu_exe.cd_prestador ), NULL, 'N', 'S' ),
                               vcm.cd_tipo_atendimento_intermed,
                               vcm.tp_conta,
                               vcm.cd_conta_medica,
                               vcm.cd_lancamento_filho,
                               vcm.tp_item,
                               vcm.cd_reduzido_ec,
                               vcm.cd_reduzido_re,
                               vcm.cd_reduzido_cr,
                               vcm.cd_setor,
                               vcm.cd_item_res,
                               vcm.sn_contabiliza_franquia,
                               Nvl( us.cd_plano, -1 ),
                               Decode( vcm.tp_conta, 'I', NULL, pro.cd_item_despesa ),
--                               Decode( Nvl( Nvl( pr.sn_captation, pr_exe.sn_captation ), 'N'), 'S', 'CP', Decode( Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ), 'D', cCfgCooperado, 'I', 'C', Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ) ) ),

                               CASE
                                 WHEN Nvl( Nvl( pr.sn_captation, pr_exe.sn_captation ), 'N') = 'S' AND ft.sn_nao_aplicar_captation = 'S' THEN
                                   'CP'
                                 ELSE
                                   Decode( Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ), 'D', cCfgCooperado, 'I', 'C', Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ) )
                               END,

                               Nvl( Nvl( pr.tp_contratualizacao, pr_exe.tp_contratualizacao ), 'D'),
                               pro.tp_natureza,
                               gp.tp_gru_pro,
                               vcm.tp_beneficiario,
                               vcm.rowid_conta,
                               vcm.rowid_itconta,
                               vcm.rowid_equipe,
                               vcm.cd_lancamento_equipe
                      ORDER BY Decode( Nvl( pu.cd_prestador, pu_exe.cd_prestador ), NULL, 'N', 'S' ),
                               Nvl( us.cd_plano, -1 ),
                               Decode( vcm.tp_conta, 'I', NULL, pro.cd_item_despesa ),

                               CASE
                                 WHEN Nvl( Nvl( pr.sn_captation, pr_exe.sn_captation ), 'N') = 'S' AND ft.sn_nao_aplicar_captation = 'S' THEN
                                   'CP'
                                 ELSE
                                   Decode( Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ), 'D', cCfgCooperado, 'I', 'C', Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ) )
                               END,

--                             Decode( Nvl( Nvl( pr.sn_captation, pr_exe.sn_captation ), 'N'), 'S', 'CP', Decode( Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ), 'D', cCfgCooperado, 'I', 'C', Nvl( pr.tp_credenciamento, pr_exe.tp_credenciamento ) ) ),
                               vcm.cd_tipo_atendimento_intermed,
                               Nvl( Nvl( pr.tp_contratualizacao, pr_exe.tp_contratualizacao ), 'D') ) LOOP

        cSnContabilizaFranquia := 'N';
        nCdReduzido6 := NULL;

        nCdReduzidoCRAssumidaACA := NULL;
        nCdReduzidoCRAssumidaACP := NULL;
        nCdReduzidoCRAssumidaANC := NULL;
        nCdReduzidoCRAvisoACA := NULL;
        nCdReduzidoCRAvisoACP := NULL;
        nCdReduzidoCRAvisoANC := NULL;

--      IF DBAPS.PKG_UNIMED.LE_UNIMED IS NULL THEN
          cSnContabilizaFranquia := 'N';

          OPEN  cPlanoLctoMens ( rVCM.CD_PLANO, nCdGrupoFranquia );
          FETCH cPlanoLctoMens INTO cSnContabilizaFranquia;

          IF cPlanoLctoMens%FOUND THEN
            cSnContabilizaFranquia := 'N';
          ELSE
            cSnContabilizaFranquia := 'S';
            nCdReduzido6 := DBAPS.FNC_CONTA_CONTABIL_RECEITA( NULL, nCdGrupoFranquia, 'AT', nCdSetor, nCdItemRes, nCdReduzido2, rVCM.cd_plano, dDataInicial );
          END IF;

          CLOSE cPlanoLctoMens;
--      END IF;

        nIndex := Nvl( nIndex, 0 ) + 1;

        IF nIndex >= 10000 THEN
          COMMIT;
          nIndex := 0;
        END IF;

        cTpCredenciamento := rVCM.tp_credenciamento;

        IF rVCM.tp_contratualizacao = 'I' THEN
          cTpCredenciamento := 'RI';
        ELSIF rVCM.sn_unimed = 'S' AND rVCM.tp_beneficiario = 'LR'  THEN
          cTpCredenciamento := 'AC';
        ELSIF rVCM.sn_unimed = 'S' AND rVCM.tp_beneficiario = 'LO'  THEN
          cTpCredenciamento := 'AE';
        END IF;

        bLocated := FALSE;

        IF rVCM.TP_CONTA = 'I' THEN
          IF rVCM.TP_GRU_PRO = 'SP' THEN
            --* SP-Serviços Profissionais
            cTpProcedimento := 'HM';
          ELSIF rVCM.TP_GRU_PRO = 'SD' OR rVCM.TP_NATUREZA = '5' THEN
              --* SD-Serviços Diagnosticos
            cTpProcedimento := 'EX';
          ELSIF rVCM.TP_GRU_PRO IN ('MM', 'OU', 'SH', 'TX', 'DI') THEN
            --* MM-MATERIAIS E MEDICAMENTOS(NÃO USADO) / OU-OUTROS / SH-SERVIÇOS HOSPITALARES / TX-TAXAS / DI-DIARIAS
            cTpProcedimento := 'OL';
          ELSIF rVCM.TP_GRU_PRO = 'MT' OR rVCM.TP_GRU_PRO = 'MD' OR rVCM.TP_GRU_PRO = 'OP' THEN
            --* MT-MATERIAIS / MD-MEDICAMENTOS / OP-ORTESE, PROTESE E MATERIAIS ESPECIAIS
            cTpProcedimento := rVCM.TP_GRU_PRO;
          ELSIF rVCM.TP_GRU_PRO = 'TE' OR rVCM.TP_NATUREZA = '8' THEN
            --* TE-TERAPIA
            cTpProcedimento := rVCM.TP_GRU_PRO;
          ELSE
            cTpProcedimento := 'TD';
          END IF;

          --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DA VARIAVEL COM PLANO
          FOR nI IN 1..VCFG_CTB_DESP_GP.Count LOOP
            IF VCFG_CTB_DESP_GP(nI).CD_PLANO = Nvl( rVCM.cd_plano, -1 ) AND
              VCFG_CTB_DESP_GP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
              VCFG_CTB_DESP_GP(nI).TP_CREDENCIAMENTO = cTpCredenciamento AND
              VCFG_CTB_DESP_GP(nI).TP_PROCEDIMENTO = cTpProcedimento THEN
              bLocated := TRUE;
              nCdReduzidoEC := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
              nCdItemRes := VCFG_CTB_DESP_GP(nI).CD_ITEM_RES;
              nCdSetor := VCFG_CTB_DESP_GP(nI).CD_SETOR;
              nCdReduzidoRE := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_RE;
              nCdReduzidoCR := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR;

              nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
              nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
              nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
              nCdReduzidoCRAvisoACA := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_AVISO_ACA;
              nCdReduzidoCRAvisoACP := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_AVISO_ACP;
              nCdReduzidoCRAvisoANC := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_AVISO_ANC;
              EXIT;
            END IF;
            IF Nvl( rVCM.cd_plano, -1 ) < VCFG_CTB_DESP(nI).CD_PLANO THEN
              EXIT;
            END IF;
          END LOOP;

          IF NOT bLocated THEN
            --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DA VARIAVEL SEM PLANO
            FOR nI IN 1..VCFG_CTB_DESP_SP_GP.Count LOOP
              IF VCFG_CTB_DESP_SP_GP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
                VCFG_CTB_DESP_SP_GP(nI).TP_CREDENCIAMENTO = cTpCredenciamento AND
                VCFG_CTB_DESP_SP_GP(nI).TP_PROCEDIMENTO = cTpProcedimento THEN
                bLocated := TRUE;
                nCdReduzidoEC := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
                nCdItemRes := VCFG_CTB_DESP_SP_GP(nI).CD_ITEM_RES;
                nCdSetor := VCFG_CTB_DESP_SP_GP(nI).CD_SETOR;
                nCdReduzidoRE := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_RE;
                nCdReduzidoCR := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR;

                nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
                nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
                nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
                nCdReduzidoCRAvisoACA := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_AVISO_ACA;
                nCdReduzidoCRAvisoACP := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_AVISO_ACP;
                nCdReduzidoCRAvisoANC := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_AVISO_ANC;
                EXIT;
              END IF;
              IF Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) < VCFG_CTB_DESP(nI).CD_ITEM_DESPESA THEN
                EXIT;
              END IF;
            END LOOP;
          END IF;

          IF NOT bLocated THEN
            --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DO PRESTADOR COM PLANO
            FOR nI IN 1..VCFG_CTB_DESP_GP.Count LOOP
              IF VCFG_CTB_DESP_GP(nI).CD_PLANO = Nvl( rVCM.CD_PLANO, -1 ) AND
                VCFG_CTB_DESP_GP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
                VCFG_CTB_DESP_GP(nI).TP_CREDENCIAMENTO =  rVCM.TP_CREDENCIAMENTO AND
                VCFG_CTB_DESP_GP(nI).TP_PROCEDIMENTO = cTpProcedimento THEN
                bLocated := TRUE;
                nCdReduzidoEC := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
                nCdItemRes := VCFG_CTB_DESP_GP(nI).CD_ITEM_RES;
                nCdSetor := VCFG_CTB_DESP_GP(nI).CD_SETOR;
                nCdReduzidoRE := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_RE;
                nCdReduzidoCR := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR;

                nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
                nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
                nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
                nCdReduzidoCRAvisoACA := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_AVISO_ACA;
                nCdReduzidoCRAvisoACP := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_AVISO_ACP;
                nCdReduzidoCRAvisoANC := VCFG_CTB_DESP_GP(nI).CD_REDUZIDO_CR_AVISO_ANC;
                EXIT;
              END IF;
              IF Nvl( rVCM.cd_plano, -1 ) < VCFG_CTB_DESP(nI).CD_PLANO THEN
                EXIT;
              END IF;
            END LOOP;
          END IF;

          IF NOT bLocated THEN
            --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DO PRESTADOR SEM PLANO
            FOR nI IN 1..VCFG_CTB_DESP_SP_GP.Count LOOP
              IF VCFG_CTB_DESP_SP_GP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
                VCFG_CTB_DESP_SP_GP(nI).TP_CREDENCIAMENTO =  rVCM.TP_CREDENCIAMENTO AND
                VCFG_CTB_DESP_SP_GP(nI).TP_PROCEDIMENTO = cTpProcedimento THEN
                bLocated := TRUE;
                nCdReduzidoEC := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
                nCdItemRes := VCFG_CTB_DESP_SP_GP(nI).CD_ITEM_RES;
                nCdSetor := VCFG_CTB_DESP_SP_GP(nI).CD_SETOR;
                nCdReduzidoRE := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_RE;
                nCdReduzidoCR := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR;

                nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
                nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
                nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
                nCdReduzidoCRAvisoACA := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_AVISO_ACA;
                nCdReduzidoCRAvisoACP := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_AVISO_ACP;
                nCdReduzidoCRAvisoANC := VCFG_CTB_DESP_SP_GP(nI).CD_REDUZIDO_CR_AVISO_ANC;
                EXIT;
              END IF;
              IF Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) < VCFG_CTB_DESP(nI).CD_ITEM_DESPESA THEN
                EXIT;
              END IF;
            END LOOP;
          END IF;

        END IF;

        IF NOT bLocated THEN

          --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DA VARIAVEL COM PLANO
          FOR nI IN 1..VCFG_CTB_DESP.Count LOOP
            IF VCFG_CTB_DESP(nI).CD_PLANO = Nvl( rVCM.cd_plano, -1 ) AND
              VCFG_CTB_DESP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
              VCFG_CTB_DESP(nI).TP_CREDENCIAMENTO = cTpCredenciamento AND
              VCFG_CTB_DESP(nI).TP_PROCEDIMENTO = 'TD' THEN
              bLocated := TRUE;
              nCdReduzidoEC := VCFG_CTB_DESP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
              nCdItemRes := VCFG_CTB_DESP(nI).CD_ITEM_RES;
              nCdSetor := VCFG_CTB_DESP(nI).CD_SETOR;
              nCdReduzidoRE := VCFG_CTB_DESP(nI).CD_REDUZIDO_RE;
              nCdReduzidoCR := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR;

              nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
              nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
              nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
              nCdReduzidoCRAvisoACA := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_AVISO_ACA;
              nCdReduzidoCRAvisoACP := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_AVISO_ACP;
              nCdReduzidoCRAvisoANC := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_AVISO_ANC;
              EXIT;
            END IF;
            IF Nvl( rVCM.cd_plano, -1 ) < VCFG_CTB_DESP(nI).CD_PLANO  THEN
              EXIT;
            END IF;
          END LOOP;

          IF NOT bLocated THEN
            --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DA VARIAVEL SEM PLANO
            nI := 1;
            FOR nI IN 1..VCFG_CTB_DESP_SP.Count LOOP
              IF VCFG_CTB_DESP_SP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
                VCFG_CTB_DESP_SP(nI).TP_CREDENCIAMENTO = cTpCredenciamento AND
                VCFG_CTB_DESP_SP(nI).TP_PROCEDIMENTO = 'TD' THEN
                bLocated := TRUE;
                nCdReduzidoEC := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
                nCdItemRes := VCFG_CTB_DESP_SP(nI).CD_ITEM_RES;
                nCdSetor := VCFG_CTB_DESP_SP(nI).CD_SETOR;
                nCdReduzidoRE := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_RE;
                nCdReduzidoCR := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR;

                nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
                nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
                nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
                nCdReduzidoCRAvisoACA := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_AVISO_ACA;
                nCdReduzidoCRAvisoACP := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_AVISO_ACP;
                nCdReduzidoCRAvisoANC := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_AVISO_ANC;
                EXIT;
              END IF;
              IF Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) < VCFG_CTB_DESP(nI).CD_ITEM_DESPESA THEN
                EXIT;
              END IF;
            END LOOP;
          END IF;

          IF NOT bLocated THEN
            --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DO PRESTADOR COM PLANO
            FOR nI IN 1..VCFG_CTB_DESP.Count LOOP
              IF VCFG_CTB_DESP(nI).CD_PLANO = Nvl( rVCM.CD_PLANO, -1 ) AND
                VCFG_CTB_DESP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
                VCFG_CTB_DESP(nI).TP_CREDENCIAMENTO =  rVCM.TP_CREDENCIAMENTO AND
                VCFG_CTB_DESP(nI).TP_PROCEDIMENTO = 'TD' THEN
                bLocated := TRUE;
                nCdReduzidoEC := VCFG_CTB_DESP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
                nCdItemRes := VCFG_CTB_DESP(nI).CD_ITEM_RES;
                nCdSetor := VCFG_CTB_DESP(nI).CD_SETOR;
                nCdReduzidoRE := VCFG_CTB_DESP(nI).CD_REDUZIDO_RE;
                nCdReduzidoCR := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR;

                nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
                nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
                nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
                nCdReduzidoCRAvisoACA := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_AVISO_ACA;
                nCdReduzidoCRAvisoACP := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_AVISO_ACP;
                nCdReduzidoCRAvisoANC := VCFG_CTB_DESP(nI).CD_REDUZIDO_CR_AVISO_ANC;
                EXIT;
              END IF;
              IF Nvl( rVCM.cd_plano, -1 ) < VCFG_CTB_DESP(nI).CD_PLANO THEN
                EXIT;
              END IF;
            END LOOP;
          END IF;

          IF NOT bLocated THEN
            --* LOCALIZANDO A CLASSIFICACAO CONTABIL PELO TIPO DE CREDENCIAMENTO DO PRESTADOR SEM PLANO
            FOR nI IN 1..VCFG_CTB_DESP_SP.Count LOOP
              IF VCFG_CTB_DESP_SP(nI).CD_ITEM_DESPESA = Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) AND
                VCFG_CTB_DESP_SP(nI).TP_CREDENCIAMENTO =  rVCM.TP_CREDENCIAMENTO AND
                VCFG_CTB_DESP_SP(nI).TP_PROCEDIMENTO = 'TD' THEN
                bLocated := TRUE;
                nCdReduzidoEC := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_EVENTO_CONHECIDO;
                nCdItemRes := VCFG_CTB_DESP_SP(nI).CD_ITEM_RES;
                nCdSetor := VCFG_CTB_DESP_SP(nI).CD_SETOR;
                nCdReduzidoRE := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_RE;
                nCdReduzidoCR := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR;

                nCdReduzidoCRAssumidaACA := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACA;
                nCdReduzidoCRAssumidaACP := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_ASSUMIDA_ACP;
                nCdReduzidoCRAssumidaANC :=VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_ASSUMIDA_ANC;
                nCdReduzidoCRAvisoACA := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_AVISO_ACA;
                nCdReduzidoCRAvisoACP := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_AVISO_ACP;
                nCdReduzidoCRAvisoANC := VCFG_CTB_DESP_SP(nI).CD_REDUZIDO_CR_AVISO_ANC;
                EXIT;
              END IF;
              IF Nvl( rVCM.CD_ITEM_DESPESA, nCdItemDspIntern ) < VCFG_CTB_DESP(nI).CD_ITEM_DESPESA THEN
                EXIT;
              END IF;
            END LOOP;
          END IF;

        END IF;

        IF bLocated THEN

          IF rVCM.tp_conta = 'A' THEN
            BEGIN
              IF DBAPS.PKG_UNIMED.LE_UNIMED IS NULL THEN
                UPDATE dbaps.itremessa_prestador ip
      	          SET cd_reduzido = nCdReduzidoEC
      	              ,cd_reduzido_re = nCdReduzidoRE
                      ,cd_reduzido_cr = nCdReduzidoCR
                      ,cd_reduzido_patrimonial = nCdReduzido6
      	              ,cd_setor = nCdSetor
      	              ,cd_item_res = nCdItemRes
                      ,sn_contabiliza_franquia = cSnContabilizaFranquia
                      ,cd_reduzido_cr_aviso_acp = nCdReduzidoCRAvisoACP
                      ,cd_reduzido_cr_aviso_aca = nCdReduzidoCRAvisoACA
                      ,cd_reduzido_cr_aviso_anc = nCdReduzidoCRAvisoANC
                      ,cd_reduzido_cr_assumida_acp = nCdReduzidoCRAssumidaACP
                      ,cd_reduzido_cr_assumida_aca = nCdReduzidoCRAssumidaACA
                      ,cd_reduzido_cr_assumida_anc = nCdReduzidoCRAssumidaANC
                  WHERE cd_remessa = rVCM.cd_conta_medica
                    AND cd_lancamento = rVCM.cd_lancamento_filho;
              END IF;

              UPDATE dbaps.itremessa_prestador_equipe ip
  	            SET cd_reduzido = nCdReduzidoEC
  	                ,cd_reduzido_re = nCdReduzidoRE
                    ,cd_reduzido_cr = nCdReduzidoCR
                    ,cd_reduzido_patrimonial = nCdReduzido6
  	                ,cd_setor = nCdSetor
  	                ,cd_item_res = nCdItemRes
                    ,cd_reduzido_cr_aviso_acp = nCdReduzidoCRAvisoACP
                    ,cd_reduzido_cr_aviso_aca = nCdReduzidoCRAvisoACA
                    ,cd_reduzido_cr_aviso_anc = nCdReduzidoCRAvisoANC
                    ,cd_reduzido_cr_assumida_acp = nCdReduzidoCRAssumidaACP
                    ,cd_reduzido_cr_assumida_aca = nCdReduzidoCRAssumidaACA
                    ,cd_reduzido_cr_assumida_anc = nCdReduzidoCRAssumidaANC
                WHERE cd_remessa = rVCM.cd_conta_medica
                  AND cd_lancamento = rVCM.cd_lancamento_filho
                  AND cd_equipe_medica_lancmto = rVCM.cd_lancamento_equipe;
--                  AND ROWID = rVCM.rowid_equipe;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          ELSE
            IF DBAPS.PKG_UNIMED.LE_UNIMED IS NULL THEN
              UPDATE dbaps.itconta_hospitalar ip
      	          SET cd_reduzido = nCdReduzidoEC
      	            ,cd_reduzido_re = nCdReduzidoRE
                    ,cd_reduzido_cr = nCdReduzidoCR
                    ,cd_reduzido_patrimonial = nCdReduzido6
      	            ,cd_setor = nCdSetor
      	            ,cd_item_res = nCdItemRes
                    ,sn_contabiliza_franquia = cSnContabilizaFranquia
                    ,cd_reduzido_cr_aviso_acp = nCdReduzidoCRAvisoACP
                    ,cd_reduzido_cr_aviso_aca = nCdReduzidoCRAvisoACA
                    ,cd_reduzido_cr_aviso_anc = nCdReduzidoCRAvisoANC
                    ,cd_reduzido_cr_assumida_acp = nCdReduzidoCRAssumidaACP
                    ,cd_reduzido_cr_assumida_aca = nCdReduzidoCRAssumidaACA
                    ,cd_reduzido_cr_assumida_anc = nCdReduzidoCRAssumidaANC
                  WHERE cd_conta_hospitalar = rVCM.cd_conta_medica
                    AND cd_lancamento = rVCM.cd_lancamento_filho;
            END IF;

            UPDATE dbaps.itconta_med ip
  	            SET cd_reduzido = nCdReduzidoEC
  	              ,cd_reduzido_re = nCdReduzidoRE
                  ,cd_reduzido_cr = nCdReduzidoCR
                  ,cd_reduzido_patrimonial = nCdReduzido6
  	              ,cd_setor = nCdSetor
  	              ,cd_item_res = nCdItemRes
                  ,cd_reduzido_cr_aviso_acp = nCdReduzidoCRAvisoACP
                  ,cd_reduzido_cr_aviso_aca = nCdReduzidoCRAvisoACA
                  ,cd_reduzido_cr_aviso_anc = nCdReduzidoCRAvisoANC
                  ,cd_reduzido_cr_assumida_acp = nCdReduzidoCRAssumidaACP
                  ,cd_reduzido_cr_assumida_aca = nCdReduzidoCRAssumidaACA
                  ,cd_reduzido_cr_assumida_anc = nCdReduzidoCRAssumidaANC
                WHERE cd_conta_hospitalar = rVCM.cd_conta_medica
                  AND cd_lancamento = rVCM.cd_lancamento_filho
                  AND ROWID = rVCM.rowid_equipe;
          END IF;

        END IF;

      END LOOP;

    END;

    FOR rPres IN ( SELECT cd_prestador FROM dbaps.prestador WHERE sn_captation = 'S' ) LOOP
      dbaps.prc_mvs_rateio_captation( rPres.cd_prestador, To_Date( PNR_MESANO_INICIAL, 'yyyymm' ), 'S' );
    END LOOP;

  END IF;

  IF PSN_CUSTO = 'S' THEN
    NULL;
  END IF;

  COMMIT;

  DBAPS.PKG_SOULSAUDE.ATRIBUI_MODO_IMPORTA_XML(NULL);

EXCEPTION
  WHEN OTHERS THEN
    DBAPS.PKG_SOULSAUDE.ATRIBUI_MODO_IMPORTA_XML(NULL);
    Raise_Application_Error( -20001, SQLERRM );
END;
/

GRANT EXECUTE ON dbaps.prc_ident_ctactb_custos TO dbamv;
GRANT EXECUTE ON dbaps.prc_ident_ctactb_custos TO dbaportal;
GRANT EXECUTE ON dbaps.prc_ident_ctactb_custos TO dbasgu;
GRANT EXECUTE ON dbaps.prc_ident_ctactb_custos TO mv2000;
GRANT EXECUTE ON dbaps.prc_ident_ctactb_custos TO mvintegra;
