select * from cyclos_users limit 2;

--	mask int8 NOT NULL,
--	rotate_bits int4 NOT NULL,
select mask, rotate_bits from cyclos_id_cipher_rounds order by order_index;

select IdCypher(5237);
select IdDecypher(8188815303409523290);

CREATE or replace FUNCTION IdCypher(int8) RETURNS int8 AS $$
DECLARE
  vmask  int8[];
  vrbits int4[];
  p bit(64); len int4;
begin
	vmask := array(select mask        from cyclos_id_cipher_rounds order by order_index);
    vrbits:= array(select rotate_bits from cyclos_id_cipher_rounds order by order_index);
    p := ($1::bit(64)); len := array_length(vmask,1);
   	for pos in 1..len loop 
		p := (p >> vrbits[pos]) | (p << (64-vrbits[pos])); -- Rotation
		p := p # (vmask[pos]::bit(64));                    -- XOR
	end loop;
	return (p::int8);
end;
$$ LANGUAGE plpgsql;

CREATE or replace FUNCTION IdDecypher(int8) RETURNS int8 AS $$
DECLARE
  vmask  int8[];
  vrbits int4[];
  p bit(64); len int4;
begin
	vmask := array(select mask        from cyclos_id_cipher_rounds order by order_index);
    vrbits:= array(select rotate_bits from cyclos_id_cipher_rounds order by order_index);
    p := ($1::bit(64)); len := array_length(vmask,1);
   	for pos in reverse len..1 loop
		p := p # (vmask[pos]::bit(64));                    -- XOR
		p := (p << vrbits[pos]) | (p >> (64-vrbits[pos])); -- Rotation
	end loop;
	return (p::int8);
end;
$$ LANGUAGE plpgsql;


