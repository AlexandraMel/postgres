use strict;
use warnings;

use PostgresNode;
use TestLib;
use Test::More tests => 35;

program_help_ok('vacuumdb');
program_version_ok('vacuumdb');
program_options_handling_ok('vacuumdb');

my $node = get_new_node('main');
$node->init;
$node->start;

$node->issues_sql_like(
	[ 'vacuumdb', 'postgres' ],
	qr/statement: VACUUM.*;/,
	'SQL VACUUM run');
$node->issues_sql_like(
	[ 'vacuumdb', '-f', 'postgres' ],
	qr/statement: VACUUM \(FULL\).*;/,
	'vacuumdb -f');
$node->issues_sql_like(
	[ 'vacuumdb', '-F', 'postgres' ],
	qr/statement: VACUUM \(FREEZE\).*;/,
	'vacuumdb -F');
$node->issues_sql_like(
	[ 'vacuumdb', '-zj2', 'postgres' ],
	qr/statement: VACUUM \(ANALYZE\).*;/,
	'vacuumdb -zj2');
$node->issues_sql_like(
	[ 'vacuumdb', '-Z', 'postgres' ],
	qr/statement: ANALYZE.*;/,
	'vacuumdb -Z');
$node->issues_sql_like(
	[ 'vacuumdb', '--disable-page-skipping', 'postgres' ],
	qr/statement: VACUUM \(DISABLE_PAGE_SKIPPING\).*;/,
	'vacuumdb --disable-page-skipping');
$node->issues_sql_like(
	[ 'vacuumdb', '--skip-locked', 'postgres' ],
	qr/statement: VACUUM \(SKIP_LOCKED\).*;/,
	'vacuumdb --skip-locked');
$node->issues_sql_like(
	[ 'vacuumdb', '--skip-locked', '--analyze-only', 'postgres' ],
	qr/statement: ANALYZE \(SKIP_LOCKED\).*;/,
	'vacuumdb --skip-locked --analyze-only');
$node->command_fails(
	[ 'vacuumdb', '--analyze-only', '--disable-page-skipping', 'postgres' ],
	'--analyze-only and --disable-page-skipping specified together');
$node->command_ok([qw(vacuumdb -Z --table=pg_am dbname=template1)],
	'vacuumdb with connection string');

$node->command_fails(
	[qw(vacuumdb -Zt pg_am;ABORT postgres)],
	'trailing command in "-t", without COLUMNS');

# Unwanted; better if it failed.
$node->command_ok(
	[qw(vacuumdb -Zt pg_am(amname);ABORT postgres)],
	'trailing command in "-t", with COLUMNS');

$node->safe_psql(
	'postgres', q|
  CREATE TABLE "need""q(uot" (")x" text);
  CREATE TABLE vactable (a int, b int);

  CREATE FUNCTION f0(int) RETURNS int LANGUAGE SQL AS 'SELECT $1 * $1';
  CREATE FUNCTION f1(int) RETURNS int LANGUAGE SQL AS 'SELECT f0($1)';
  CREATE TABLE funcidx (x int);
  INSERT INTO funcidx VALUES (0),(1),(2),(3);
  CREATE INDEX i0 ON funcidx ((f1(x)));
|);
$node->command_ok([qw|vacuumdb -Z --table="need""q(uot"(")x") postgres|],
	'column list');
$node->command_fails(
	[qw|vacuumdb -Zt funcidx postgres|],
	'unqualifed name via functional index');

$node->command_fails(
	[ 'vacuumdb', '--analyze', '--table', 'vactable(c)', 'postgres' ],
	'incorrect column name with ANALYZE');
$node->issues_sql_like(
	[ 'vacuumdb', '--analyze', '--table', 'vactable(a, b)', 'postgres' ],
	qr/statement: VACUUM \(ANALYZE\) public.vactable\(a, b\);/,
	'vacuumdb --analyze with complete column list');
$node->issues_sql_like(
	[ 'vacuumdb', '--analyze-only', '--table', 'vactable(b)', 'postgres' ],
	qr/statement: ANALYZE public.vactable\(b\);/,
	'vacuumdb --analyze-only with partial column list');
