PROMPT CREATE OR REPLACE PROCEDURE dbaps.prc_gera_reembolso_ressarc_sus
CREATE OR REPLACE PROCEDURE dbaps.prc_gera_reembolso_ressarc_sus (PCD_RESSARCIMENTO_SUS IN NUMBER, PCD_USUARIO_LOGADO IN VARCHAR2) IS

  /**************************************************************
    <objeto>
    <nome>prc_gera_reembolso_ressarc_sus</nome>
    <usuario>Dellanio Alencar</usuario>
    <alteracao>18/02/2020 14:32</alteracao>
    <descricao>Procedure responsavel por gerar os reembolsos referente ao Ressarcimento SUS.</descricao>
    <parametro>PCD_RESSARCIMENTO_SUS - Codigo do Ressarcimento SUS</parametro>
    <versao>1.4</versao>
    <tags>ressarcimento,ressarcimento_sus,sus,reembolso</tags>
    </objeto>
    ***************************************************************/

	/***********************************************************
    *                       CURSORES                          *
    ***********************************************************/
	CURSOR cAtendimentos(P_CD_RESSARCIMENTO_SUS IN NUMBER) IS
		SELECT
		  I.NR_ATENDIMENTO,
      LPad(SubStr(I.CD_CCO, 0, Length(I.CD_CCO)-2), 10, 0) CD_CCO,
      LPad(SubStr(I.CD_CCO, Length(I.CD_CCO)-1, 2), 2, 0) NR_DIV_CCO,
      Max(I.DT_INICIO),
      Min(I.DT_INICIO) DT_ATENDIMENTO,
      Max(I.DT_FIM) DT_ALTA,
      I.NM_MUNICIPIO,
      I.CD_UF,
      Count(1) NR_QTD,
      Sum(I.VL_PROCEDIMENTO) VL_QTD,
      I.NM_UPS
		FROM
		  DBAPS.VALIDA_ITEM_RESS_SUS_ANEXO V,
      DBAPS.RESSARCIMENTO_SUS R,
      DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO I
		WHERE
		  R.CD_RESSARCIMENTO_SUS = I.CD_RESSARCIMENTO_SUS
		  AND V.CD_ITEM_RESSARCIMENT_SUS_ANEXO = I.CD_ITEM_RESSARCIMENT_SUS_ANEXO
      AND V.TP_VALIDACAO <> 'E'
		  AND NOT EXISTS (SELECT 1 FROM DBAPS.REEMBOLSO REEM WHERE REEM.CD_RESSARCIMENTO_SUS = R.CD_RESSARCIMENTO_SUS)
		  AND R.CD_RESSARCIMENTO_SUS = P_CD_RESSARCIMENTO_SUS
		GROUP BY I.NR_ATENDIMENTO, I.CD_CCO, I.NM_MUNICIPIO, I.CD_UF, I.NM_UPS
		ORDER BY I.CD_CCO, I.NR_ATENDIMENTO;
  --
	CURSOR cObsAtendimentos(P_CD_RESSARCIMENTO_SUS IN NUMBER, P_NR_ATENDIMENTO IN NUMBER, P_CD_CCO IN VARCHAR2, P_NR_DIV_CCO IN VARCHAR2) IS
		SELECT DISTINCT
		  I.NR_ATENDIMENTO,
      LPad(SubStr(I.CD_CCO, 0, Length(I.CD_CCO)-2), 10, 0) CD_CCO,
      LPad(SubStr(I.CD_CCO, Length(I.CD_CCO)-1, 2), 2, 0) NR_DIV_CCO,
      I.DS_ATENDIMENTO
		FROM
		  DBAPS.VALIDA_ITEM_RESS_SUS_ANEXO V,
      DBAPS.RESSARCIMENTO_SUS R,
      DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO I
		WHERE
		  R.CD_RESSARCIMENTO_SUS = I.CD_RESSARCIMENTO_SUS
		  AND V.CD_ITEM_RESSARCIMENT_SUS_ANEXO = I.CD_ITEM_RESSARCIMENT_SUS_ANEXO
		  AND R.CD_RESSARCIMENTO_SUS = P_CD_RESSARCIMENTO_SUS
		  AND I.NR_ATENDIMENTO = P_NR_ATENDIMENTO
		  AND LPad(SubStr(I.CD_CCO, 0, Length(I.CD_CCO)-2), 10, 0) = P_CD_CCO
      AND LPad(SubStr(I.CD_CCO, Length(I.CD_CCO)-1, 2), 2, 0) = P_NR_DIV_CCO
		  AND I.DS_ATENDIMENTO IS NOT NULL
		ORDER BY I.CD_CCO, I.NR_ATENDIMENTO;

	CURSOR cItensAtendimentos(P_CD_RESSARCIMENTO_SUS IN NUMBER, P_NR_ATENDIMENTO IN NUMBER, P_CD_CCO IN VARCHAR2, P_NR_DIV_CCO IN VARCHAR2) IS
		SELECT LPad(SubStr(I.CD_CCO, 0, Length(I.CD_CCO)-2), 10, 0) CD_CCO,
           LPad(SubStr(I.CD_CCO, Length(I.CD_CCO)-1, 2), 2, 0) NR_DIV_CCO,
           I.NR_ATENDIMENTO,
           DBAPS.FNC_DEPARA_SUS_PROCEDIMENTO(I.CD_PROCEDIMENTO, SYSDATE) CD_PROCEDIMENTO,
           Sum(decode(V.TP_VALIDACAO, 'I', 0, I.VL_PROCEDIMENTO)) VL_QTD,
           Sum(I.VL_PROCEDIMENTO) VL_QTD_ORIGINAL,
           Count(1) NR_QTD,
           R.DT_OFICIO
		  FROM DBAPS.VALIDA_ITEM_RESS_SUS_ANEXO V,
           DBAPS.RESSARCIMENTO_SUS R,
           DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO I
		WHERE R.CD_RESSARCIMENTO_SUS = I.CD_RESSARCIMENTO_SUS
		  AND V.CD_ITEM_RESSARCIMENT_SUS_ANEXO = I.CD_ITEM_RESSARCIMENT_SUS_ANEXO
		  AND R.CD_RESSARCIMENTO_SUS = P_CD_RESSARCIMENTO_SUS
		  AND I.NR_ATENDIMENTO = P_NR_ATENDIMENTO
		  AND LPad(SubStr(I.CD_CCO, 0, Length(I.CD_CCO)-2), 10, 0) = P_CD_CCO
      AND LPad(SubStr(I.CD_CCO, Length(I.CD_CCO)-1, 2), 2, 0) = P_NR_DIV_CCO
		GROUP BY I.CD_CCO, I.NR_ATENDIMENTO, DBAPS.FNC_DEPARA_SUS_PROCEDIMENTO(I.CD_PROCEDIMENTO, SYSDATE), R.DT_OFICIO;

	CURSOR cCriticasAtendimentos(P_CD_RESSARCIMENTO_SUS IN NUMBER, P_NR_ATENDIMENTO IN NUMBER, P_CD_CCO IN VARCHAR2, P_NR_DIV_CCO IN VARCHAR2) IS
	  SELECT DISTINCT I.NR_ATENDIMENTO,
           I.CD_CCO,
           V.DS_MENSAGEM,
           V.TP_VALIDACAO,
           DBAPS.FNC_DEPARA_SUS_PROCEDIMENTO(I.CD_PROCEDIMENTO, SYSDATE) CD_PROCEDIMENTO
		  FROM DBAPS.VALIDA_ITEM_RESS_SUS_ANEXO V,
           DBAPS.RESSARCIMENTO_SUS R,
           DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO I
		WHERE R.CD_RESSARCIMENTO_SUS = I.CD_RESSARCIMENTO_SUS
		  AND V.CD_ITEM_RESSARCIMENT_SUS_ANEXO = I.CD_ITEM_RESSARCIMENT_SUS_ANEXO
		  AND R.CD_RESSARCIMENTO_SUS = P_CD_RESSARCIMENTO_SUS
		  AND I.NR_ATENDIMENTO = P_NR_ATENDIMENTO
		  AND LPad(SubStr(I.CD_CCO, 0, Length(I.CD_CCO)-2), 10, 0) = P_CD_CCO
      AND LPad(SubStr(I.CD_CCO, Length(I.CD_CCO)-1, 2), 2, 0) = P_NR_DIV_CCO
		  AND V.DS_MENSAGEM IS NOT NULL
		ORDER BY I.CD_CCO, I.NR_ATENDIMENTO, V.TP_VALIDACAO;

    CURSOR cUsuario(P_CD_CCO IN NUMBER,
                    P_NR_DIV_CCO IN NUMBER) IS
		SELECT U.CD_MATRICULA,
           U.CD_MULTI_EMPRESA,
           Nvl(TIT.CD_FORNECEDOR, U.CD_FORNECEDOR) CD_FORNECEDOR
      FROM DBAPS.USUARIO U,
           DBAPS.USUARIO TIT
		 WHERE LPad(U.CD_CCO, 10, 0) = P_CD_CCO
       AND LPad(U.NR_DIV_CCO, 2, 0) = P_NR_DIV_CCO
       AND U.CD_MATRICULA_TEM = TIT.CD_MATRICULA (+);

    --- VARIAVEIS
	  nSeqReembolso				        NUMBER;
	  vObs						            VARCHAR2(4000);
	  vCriticas					          VARCHAR2(4000);
	  nVlProcedimentoPagar		    NUMBER;
	  vVerificaProcAtendImpugnado	NUMBER;
    rUsuario                    cUsuario%ROWTYPE;

BEGIN

	--SAVEPOINT PONTO;

	BEGIN
		FOR rAtendimentos IN cAtendimentos(PCD_RESSARCIMENTO_SUS)
		LOOP
      --
			vObs := '';
			vCriticas := '';

      rUsuario := NULL;
      OPEN cUsuario(rAtendimentos.CD_CCO, rAtendimentos.NR_DIV_CCO);
      FETCH cUsuario INTO rUsuario;
      CLOSE cUsuario;

			/* nao se detectou uso para vObs
      FOR rObsAtendimentos IN cObsAtendimentos(PCD_RESSARCIMENTO_SUS, rAtendimentos.NR_ATENDIMENTO, rAtendimentos.CD_CCO)
			LOOP
				vObs := vObs || rObsAtendimentos.DS_ATENDIMENTO || CHR(10);
			END LOOP; --cObsAtendimentos

			IF (vObs = '') THEN
				vObs := NULL;
			ELSE
				vObs := Trim(vObs);
			END IF;*/

			FOR rCriticasAtendimentos IN cCriticasAtendimentos(PCD_RESSARCIMENTO_SUS, rAtendimentos.NR_ATENDIMENTO, rAtendimentos.CD_CCO, rAtendimentos.NR_DIV_CCO)
			LOOP
				vCriticas := vCriticas || rCriticasAtendimentos.CD_PROCEDIMENTO || ' : ' || NVL(rCriticasAtendimentos.DS_MENSAGEM, '')  || CHR(10);
			END LOOP; --cCriticasAtendimentos

			IF (NVL(vCriticas, '') = '') THEN
				vCriticas := NULL;
			ELSE
				vCriticas := Trim(vCriticas);
			END IF;

      IF rUsuario.CD_MATRICULA IS NOT NULL THEN

			    SELECT DBAPS.SEQ_REEMBOLSO.NEXTVAL INTO nSeqReembolso FROM DUAL;

			    INSERT INTO DBAPS.REEMBOLSO (
			    	  cd_reembolso
			    	, tp_reembolso
			    	, cd_controle_interno
			    	, cd_matricula
			    	, cd_mens_contrato
			    	, sn_quitar_mensalidade
			    	, sn_gerar_con_pag
			    	, cd_prestador
			    	, ds_prestador
			    	, ds_conselho
			    	, ds_codigo_conselho
			    	, nr_cpf_cnpj
			    	, dt_atendimento
			    	, vl_ch
			    	, vl_filme
			    	, vl_total_original
			    	, cd_con_pag
			    	, dt_cancelamento
			    	, ds_usuario_cancelamento
			    	, dt_inclusao
			    	, cd_usuario_inclusao
			    	, dt_ultima_atualizacao
			    	, cd_usuario_ultima_atualizacao
			    	, ds_observacao
			    	, cd_fornecedor
			    	, cd_especialidade
			    	, dt_vencimento
			    	, cd_tip_doc
			    	, cd_multi_empresa
			    	, cd_sip_periodo
			    	, cd_tipo_atendimento
			    	, dt_alta
			    	, tp_pessoa
			    	, tp_status
			    	, cd_tipo_endereco
			    	, nr_cep
			    	, ds_endereco
			    	, nr_endereco
			    	, ds_complemento
			    	, ds_bairro
			    	, cd_municipio
			    	, ds_municipio
			    	, cd_uf
			    	, ds_email
			    	, nr_telefone
			    	, cd_ressarcimento_sus
			    	, cd_reembolso_pai
			    	, sn_notificado
			    	, sn_recusado
			    	, nm_banco
			    	, cd_agencia
			    	, dv_agencia
			    	, nr_conta
			    	, dv_conta_corrente
			    	, ds_consideracoes_internas
			    	, cd_solicitacao_web
			    	, cd_banco
			    	, cd_tabela
			    	, ds_recibo_nota_fiscal
			    	, cd_atend_call_center
			    	, nr_protocolo_ans
			    	, cd_exp_contabilidade
            , tp_status_reembolso
			    )
			    VALUES (
			    	  nSeqReembolso                                                   -- cd_reembolso
			    	, 'R'                                                             -- tp_reembolso
			    	, rAtendimentos.NR_ATENDIMENTO                                    -- cd_controle_interno
			    	, rUsuario.CD_MATRICULA                                      -- cd_matricula
			    	, NULL                                                            -- cd_mens_contrato
			    	, 'N'                                                             -- sn_quitar_mensalidade
			    	, NULL                                                            -- sn_gerar_con_pag
			    	, NULL                                                            -- cd_prestador
			    	, SubStr(rAtendimentos.NM_UPS, 1, 50)                             -- ds_prestador
			    	, NULL                                                            -- ds_conselho
			    	, NULL                                                            -- ds_codigo_conselho
			    	, NULL                                                            -- nr_cpf_cnpj
			    	, rAtendimentos.DT_ATENDIMENTO                                    -- dt_atendimento
			    	, NULL                                                            -- vl_ch
			    	, NULL                                                            -- vl_filme
			    	, rAtendimentos.VL_QTD                                            -- vl_total_original
			    	, NULL                                                            -- cd_con_pag
			    	, NULL                                                            -- dt_cancelamento
			    	, NULL                                                            -- ds_usuario_cancelamento
			    	, SYSDATE                                                         -- dt_inclusao
			    	, Nvl(PCD_USUARIO_LOGADO,USER)                                    -- cd_usuario_inclusao
			    	, SYSDATE                                                         -- dt_ultima_atualizacao
			    	, USER                                                            -- cd_usuario_ultima_atualizacao
			    	, NULL                                                            -- ds_observacao
			    	, rUsuario.CD_FORNECEDOR                                          -- cd_fornecedor
			    	, NULL                                                            -- cd_especialidade
			    	, (SYSDATE+30) --> verificar como definir uma data de vencimento  -- dt_vencimento
			    	, NULL                                                            -- cd_tip_doc
			    	, Nvl(DBAMV.PKG_MV2000.LE_EMPRESA, rUsuario.CD_MULTI_EMPRESA)     -- cd_multi_empresa
			    	, NULL                                                            -- cd_sip_periodo
			    	, NULL                                                            -- cd_tipo_atendimento
			    	, rAtendimentos.DT_ALTA                                           -- dt_alta
			    	, 'F'                                                             -- tp_pessoa
			    	, 'E'                                                             -- tp_status
			    	, NULL                                                            -- cd_tipo_endereco
			    	, NULL                                                            -- nr_cep
			    	, NULL                                                            -- ds_endereco
			    	, NULL                                                            -- nr_endereco
			    	, NULL                                                            -- ds_complemento
			    	, NULL                                                            -- ds_bairro
			    	, NULL                                                            -- cd_municipio
			    	, rAtendimentos.NM_MUNICIPIO                                      -- ds_municipio
			    	, rAtendimentos.CD_UF                                             -- cd_uf
			    	, NULL                                                            -- ds_email
			    	, NULL                                                            -- nr_telefone
			    	, PCD_RESSARCIMENTO_SUS                                           -- cd_ressarcimento_sus
			    	, NULL                                                            -- cd_reembolso_pai
			    	, 'N'                                                             -- sn_notificado
			    	, 'N'                                                             -- sn_recusado
			    	, NULL                                                            -- nm_banco
			    	, NULL                                                            -- cd_agencia
			    	, NULL                                                            -- dv_agencia
			    	, NULL                                                            -- nr_conta
			    	, NULL                                                            -- dv_conta_corrente
			    	, vCriticas                                                       -- ds_consideracoes_internas
			    	, NULL                                                            -- cd_solicitacao_web
			    	, NULL                                                            -- cd_banco
			    	, NULL                                                            -- cd_tabela
			    	, NULL                                                            -- ds_recibo_nota_fiscal
			    	, NULL                                                            -- cd_atend_call_center
			    	, NULL                                                            -- nr_protocolo_ans
			    	, NULL                                                            -- cd_exp_contabilidade
            , '1'                                                             -- tp_status_reembolso
			    );

			      FOR rItensAtendimentos IN cItensAtendimentos(PCD_RESSARCIMENTO_SUS, rAtendimentos.NR_ATENDIMENTO, rAtendimentos.CD_CCO, rAtendimentos.NR_DIV_CCO)
			      LOOP

				      UPDATE DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO
				         SET CD_REEMBOLSO = nSeqReembolso
				       WHERE CD_RESSARCIMENTO_SUS = PCD_RESSARCIMENTO_SUS
				         AND NR_ATENDIMENTO = rAtendimentos.NR_ATENDIMENTO
                 AND LPad(SubStr(CD_CCO, 0, Length(CD_CCO)-2), 10, 0) = rAtendimentos.CD_CCO
                 AND LPad(SubStr(CD_CCO, Length(CD_CCO)-1, 2), 2, 0) = rAtendimentos.NR_DIV_CCO;

				      INSERT INTO DBAPS.ITREEMBOLSO (
					      cd_reembolso
					      , cd_procedimento
					      , vl_procedimento
					      , cd_reduzido_ec
					      , cd_reduzido_re
					      , cd_exp_contabilidade
					      , cd_setor
					      , cd_item_res
					      , qt_cobrado
					      , vl_cobrado
					      , vl_coparticipacao
					      , ds_adicional
					      , cd_usuario_inclusao
					      , dt_usuario_inclusao
					      )
				      VALUES (
					        nSeqReembolso
					      , Nvl(rItensAtendimentos.CD_PROCEDIMENTO,-1)
					      , rItensAtendimentos.VL_QTD
					      , NULL
					      , NULL
					      , NULL
					      , NULL
					      , NULL
					      , rItensAtendimentos.NR_QTD
					      , rItensAtendimentos.VL_QTD_ORIGINAL
					      , NULL
					      , NULL
					      , PCD_USUARIO_LOGADO
					      , rItensAtendimentos.DT_OFICIO
				      );

				      IF NVL(rItensAtendimentos.VL_QTD, 0) < Nvl(rItensAtendimentos.VL_QTD_ORIGINAL, 0) THEN
					      INSERT INTO DBAPS.ITREEMBOLSO_GLOSA (
						      CD_ITREEMBOLSO_GLOSA
						      , CD_REEMBOLSO
						      , CD_PROCEDIMENTO
						      , CD_MOTIVO
						      , CD_USUARIO_INCLUSAO
						      , DT_USUARIO_INCLUSAO
					      )
					      VALUES (
						      DBAPS.SEQ_ITREEMBOLSO_GLOSA.NEXTVAL
						      , nSeqReembolso
						      , rItensAtendimentos.CD_PROCEDIMENTO
						      , 9630
						      , PCD_USUARIO_LOGADO
						      , SYSDATE
					      );
				      END IF;

			      END LOOP; --cItensAtendimentos

      END IF; --ENDIF rAtendimentos.CD_MATRICULA IS NOT NULL
      --
      --
		END LOOP; --cAtendimentos

	EXCEPTION WHEN OTHERS THEN
		--ROLLBACK TO PONTO;
		RAISE_APPLICATION_ERROR(-20999,'PRC_GERA_REEMBOLSO_RESSARC_SUS: MENSAGEM => '|| sqlerrm);
	END;
	COMMIT;
END;
/

GRANT EXECUTE ON dbaps.prc_gera_reembolso_ressarc_sus TO dbamv;
GRANT EXECUTE ON dbaps.prc_gera_reembolso_ressarc_sus TO dbasgu;
GRANT EXECUTE ON dbaps.prc_gera_reembolso_ressarc_sus TO mv2000;
GRANT EXECUTE ON dbaps.prc_gera_reembolso_ressarc_sus TO mvintegra;
