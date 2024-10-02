alter table members add column active boolean not null default true;
alter table members add column creation_date timestamp(6);
alter table members add column update_date timestamp(6);
UPDATE members SET creation_date = now();
UPDATE members SET update_date = now();
UPDATE members SET active = true;