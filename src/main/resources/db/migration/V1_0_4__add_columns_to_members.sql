alter table members add column active boolean not null default true;
alter table members add column creation_date timestamp(6);