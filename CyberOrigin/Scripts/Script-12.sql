CREATE TABLE public.dashboard_indicators (
	nft_dia_amount varchar NULL,
	nft_dia_date date NULL,
	nft_hcc_amount varchar NULL,
	nft_hcc_date date NULL,
	stat_block_amount varchar NULL,
	stat_block_tsz timestamptz NULL,
	stat_erp_amount varchar NULL,
	stat_erp_tsz timestamptz NULL,
	stat_ocr_amount varchar NULL,
	stat_ocr_tsz timestamptz NULL,
	stat_ops_amount varchar NULL,
	stat_ops_tsz timestamptz NULL,
	moment timestamptz DEFAULT now() NOT NULL
);