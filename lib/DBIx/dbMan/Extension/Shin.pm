package DBIx::dbMan::Extension::Shin;

use strict;
use base 'DBIx::dbMan::Extension';

our $VERSION = '0.06';

1;

sub IDENTIFICATION { return "000001-000019-000006"; }

sub preference { return 1000000; }

sub known_actions { return [ qw/COMMAND/ ]; }

sub handle_action {
	my ($obj,%action) = @_;

	if ($action{action} eq 'COMMAND')
	{
		if ($action{cmd} =~ /^_DESC\s+(\w+)/i)
		{
			my $sql="SELECT col.column_name as ` COLUMN `,
						col.data_type as ` TYPE `,
							( case  WHEN data_type like '%int%' THEN
								substring(substring(column_type,5),1,CHAR_LENGTH(substring(column_type,5)) - 1)
							else col.character_octet_length  end ) as ` SIZE `,
						col.column_default as `DEFAULT`,
						ifnull(col.numeric_scale,0) AS ` SCALE `,
						is_nullable as NULLABLE,
						( case when col.COLUMN_KEY like '%PRI%' then 1 else 0 end ) as ` PRIMARY `,
						( case when col.COLUMN_KEY like '%UNI%' then 1 else 0 end ) as ` UNIQUE `,
						( case when col.extra like '%auto_increment%' then 1 else 0 end ) as ` AI`,
						concat(referenced_table_schema,'.',referenced_table_name,'.',referenced_column_name) as ` FK TO `
						FROM `information_schema`.`columns` as col LEFT JOIN information_schema.KEY_COLUMN_USAGE us ON( col.table_name=us.table_name AND col.table_schema=us.table_schema AND col.column_name=us.column_name and us.referenced_table_name is not null ) WHERE col.table_name like '$1' AND col.table_schema=database() ORDER BY col.ordinal_position";
			$action{sql}=$sql;
			$action{action} = 'SQL';
			$action{type} = 'select';
		}elsif($action{cmd} =~ /^\s*SQL\s*(.*)$/i)
		{
			$action{action} = 'SQL';
			$action{type} = 'do';
			$action{sql} = $1;
		}elsif($action{cmd} =~ /^\s*SHOW\s*(.*)$/i)
                {
                        $action{action} = 'SQL';
                        $action{type} = 'select';
                        $action{sql} = $1;
                }

	}
	$action{processed} = 1;
	return %action;
}

sub cmdhelp {
	return [
		'DESC <table>' => 'Describes table',
	];
}

sub objectlist {
        my ($obj,$type,$text) = @_;
		my $sth = $obj->{-dbi}->table_info(undef,$text);
		my $ret = $sth->fetchall_arrayref();
		my @all = ();
		if (defined $ret)
		{
			for (@$ret)
			{
				push @all,$_->[2] if lc $type eq 'object' || lc $type eq lc $_->[3];
			}
		}
		$sth->finish;
		return @all;
        my %action = (action => 'SQL', oper => 'complete', what => 'list', type => $type, context => $text);
        do {   
                %action = $obj->{-core}->handle_action(%action);
        } until ($action{processed});
        return @{$action{list}} if ref $action{list} eq 'ARRAY';
        return ();
}

sub cmdcomplete {
	my ($obj,$text,$line,$start) = @_;
	return () unless $obj->{-dbi}->current;
	return $obj->objectlist('TABLE') if $line =~ /^\s*_DESC\s+\S*$/i;
	return ('DESC','SHOW','SQL') if $line =~ /^\s*$/;
	return qw/DESC SHOW SQL/ if $line =~ /^\s*[A-Z]*$/i;
	return ();
}
