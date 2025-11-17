select iban,bic from membres where iban is not null and iban<>'' order by estat,iban;
select ncol, estat, tarifa, iban,bic from membres where iban is not null and iban<>'' order by estat,iban;

select tipus,estat,count(*) 
from membres 
group by tipus,estat
order by tipus,estat;

select estat, tarifa, ncol, nom, cognom1, iban, bic 
  from membres
 where estat='B' and iban<>'';

