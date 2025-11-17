-- Testing (5337 ←→ 8188815303409523290)
select IdCypher(5237);
select IdDecypher(8188815303409523290);

----------------------------------------------------------------------
-- Funció IdCypher
----------------------------------------------------------------------
CREATE or replace FUNCTION IdCypher(int8) RETURNS int8 AS $$
DECLARE
  vmask  int8[];
  vrbits int4[];
  p bit(64); len int4;
begin
	--vmask := array(select mask        from cyclos_id_cipher_rounds order by order_index); -- 
    --vrbits:= array(select rotate_bits from cyclos_id_cipher_rounds order by order_index); --
	vmask := ARRAY[4687596452497516890,-7156527613906118440,6671837687017561174,-6835056048899744251,
					3102432063105944518,-4003360362407382946,-496598595412507716,7265395970614607334]; -- Canvien a cada InitDB de Cyclos
    vrbits:= ARRAY[11,47,52,17,55,36,28,15]; -- Canvien a cada InitDB de Cyclos
    p := ($1::bit(64)); len := array_length(vmask,1);
   	for pos in 1..len loop 
		p := (p >> vrbits[pos]) | (p << (64-vrbits[pos])); -- Rotation
		p := p # (vmask[pos]::bit(64));                    -- XOR
	end loop;
	return (p::int8);
end;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------
-- Funció IdDecypher
----------------------------------------------------------------------
CREATE or replace FUNCTION IdDecypher(int8) RETURNS int8 AS $$
DECLARE
  vmask  int8[];
  vrbits int4[];
  p bit(64); len int4;
begin
	--vmask := array(select mask        from cyclos_id_cipher_rounds order by order_index);
    --vrbits:= array(select rotate_bits from cyclos_id_cipher_rounds order by order_index);
	vmask := ARRAY[4687596452497516890,-7156527613906118440,6671837687017561174,-6835056048899744251,
					3102432063105944518,-4003360362407382946,-496598595412507716,7265395970614607334]; -- Canvien a cada InitDB de Cyclos
    vrbits:= ARRAY[11,47,52,17,55,36,28,15]; -- Canvien a cada InitDB de Cyclos
    p := ($1::bit(64)); len := array_length(vmask,1);
   	for pos in reverse len..1 loop
		p := p # (vmask[pos]::bit(64));                    -- XOR
		p := (p << vrbits[pos]) | (p >> (64-vrbits[pos])); -- Rotation
	end loop;
	return (p::int8);
end;
$$ LANGUAGE plpgsql;
