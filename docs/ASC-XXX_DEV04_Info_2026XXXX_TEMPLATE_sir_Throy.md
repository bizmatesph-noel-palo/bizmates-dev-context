# ASC Project DEV04 TESTING
### [ASC-Master] - DEV04 execution 20260611


### DEV04 mst_admin_setting - backup a copy before/after running the commands
====================================================================================================
# CompanyId = 453973 
# CompanyId = 3215707 
#-------------------------------------- 
# SELECT * FROM mst_admin_setting; 
#-------------------------------------- 



====================================================================================================


# database update
====================================================================================================
# Update Old DB data
UPDATE mst_admin_setting
SET item_name = CONCAT('OLD_', item_name);


|  9 | accessToken        | tIEus_tvG0kTTJ38L8TavJUcNcaQAy3fGb7MxN0aKKA | ASC Project | 2026-05-22 12:44:05 | 2026-06-01 18:10:10 |
| 10 | refreshToken       | wPMVhDg4fmI2dnKeu80pzsP89kgSN_u8zZYPL7ZaEn8 | ASC Project | 2026-05-22 12:44:05 | 2026-06-01 18:10:10 |


# Create new for ASC
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'companyId','3215707',now(),now());
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'clientId','653967443366643',now(),now());
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'clientSecretId','8gMr_0bGAsLc3GRBe6bMaZNqkZRx4CVN-TzCub3b6hIIdqKLQ9nmVOHCg5cs6Y-y1p9PG2o2K-iFjii-D7VwRA',now(),now());
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'accessToken','tIEus_tvG0kTTJ38L8TavJUcNcaQAy3fGb7MxN0aKKA',now(),now());
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'refreshToken','wPMVhDg4fmI2dnKeu80pzsP89kgSN_u8zZYPL7ZaEn8',now(),now());



# DB Data Clean up
====================================================================================================


## Bizmates 02/01
use bizmates_new;

DELETE FROM log_monthly_rate_calculation WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_monthly_rate_calculation_pre WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_daily_rate_calculation WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_daily_rate_calculation_pre WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_sum_calculation WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_sum_calculation_pre WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_sum_calculation_history WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_freee_invoices WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_balance_transition WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_balance_transition_with_order_number WHERE created_at >= "2026-02-01 00:00:00";


## Zipan 02/01
use zipan;

DELETE FROM log_monthly_rate_calculation WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_monthly_rate_calculation_pre WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_daily_rate_calculation WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_daily_rate_calculation_pre WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_sum_calculation WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_sum_calculation_pre WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_sum_calculation_history WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_daily_rate_calculation_zipan WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_daily_rate_calculation_pre_zipan WHERE created_at >= "2026-02-01 00:00:00";

DELETE FROM log_sum_calculation_zipan WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_sum_calculation_pre_zipan WHERE created_at >= "2026-02-01 00:00:00";
DELETE FROM log_sum_calculation_history_zipan WHERE created_at >= "2026-02-01 00:00:00";


====================================================================================================


====================================================================================================
# ASC Laravel Commands
====================================================================================================
## Command Structure

# pre.sh
- command:MonthlyRateCalculationPreCommand
- command:DailyRateCalculationPreCommand

# send.sh
- command:MonthlyRateCalculationCommand
- command:SendJournalsDataCommand

====================================================================================================


### pre.sh ###
========================================================================
##== Monthly Rate Calculation (PRE) ==
php artisan command:MonthlyRateCalculationPreCommand <ExecutionDate>
##== Daily Rate Calculation (PRE) ==
php artisan command:DailyRateCalculationPreCommand <ExecutionDate>

### send.sh ###
========================================================================
##== Monthly Rate Calculation ==
php artisan command:MonthlyRateCalculationCommand <ExecutionDate>
##== SendJournalsDataCommand ==
php artisan command:SendJournalsDataCommand <ExecutionDate>

### Note: 
###  Always use the NO SEND FLAG WHEN TESTING! 
### php artisan command:SendJournalsDataCommand YYYY/MM/DD 1 

========================================================================

## Get inside docker image
====================================================================================================
docker ps
docker exec -it ls-db-migration bash
docker exec -it accounting-system bash
make php-root
====================================================================================================

sudo mv storage/logs/*.log storage/logs/archives
sudo mv storage/app/public/*.zip storage/app/public/archives


tail storage/logs/archives/laravel.log

# Command Execution per Execution Dates
====================================================================================================

##########################################################################################################################

##=== 02/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0201 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-02-01
php artisan command:DailyRateCalculationPreCommand 2026-02-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_160132_PRE.log
sudo mv storage/app/public/20260201_pre.zip storage/app/public/"20260201_PRE_(DEV04_ASC_20260611_160132)".zip

###=== SEND - 0201 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-02-01
php artisan command:SendJournalsDataCommand 2026/02/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_162621_SEND.log
sudo mv storage/app/public/20260201.zip storage/app/public/"20260201_SEND_(DEV04_ASC_20260611_162621)".zip

##=== 02/01 ====================================================================================================##

##########################################################################################################################

##=== 03/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0301 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-03-01
php artisan command:DailyRateCalculationPreCommand 2026-03-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_163357_PRE.log
sudo mv storage/app/public/20260301_pre.zip storage/app/public/"20260301_PRE_(DEV04_ASC_20260611_163357)".zip

###=== SEND - 0301 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-03-01
php artisan command:SendJournalsDataCommand 2026/03/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_165833_SEND.log
sudo mv storage/app/public/20260301.zip storage/app/public/"20260301_SEND_(DEV04_ASC_20260611_165833)".zip

##=== 03/01 ====================================================================================================##

##########################################################################################################################

##=== 04/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0401 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-04-01
php artisan command:DailyRateCalculationPreCommand 2026-04-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_170652_PRE.log
sudo mv storage/app/public/20260401_pre.zip storage/app/public/"20260401_PRE_(DEV04_ASC_20260611_170652)".zip

###=== SEND - 0401 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-04-01
php artisan command:SendJournalsDataCommand 2026/04/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_173228_SEND.log
sudo mv storage/app/public/20260401.zip storage/app/public/"20260401_SEND_(DEV04_ASC_20260611_173228)".zip

##=== 04/01 ====================================================================================================##


##########################################################################################################################

##=== 05/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0501 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-05-01
php artisan command:DailyRateCalculationPreCommand 2026-05-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_173954_PRE.log
sudo mv storage/app/public/20260501_pre.zip storage/app/public/"20260501_PRE_(DEV04_ASC_20260611_173954)".zip

###=== SEND - 0501 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-05-01
php artisan command:SendJournalsDataCommand 2026/05/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_180514_SEND.log
sudo mv storage/app/public/20260501.zip storage/app/public/"20260501_SEND_(DEV04_ASC_20260611_180514)".zip

##=== 05/01 ====================================================================================================##

##########################################################################################################################


##########################################################################################################################

##=== 06/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0601 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-06-01
php artisan command:DailyRateCalculationPreCommand 2026-06-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_181228_PRE.log
sudo mv storage/app/public/20260601_pre.zip storage/app/public/"20260601_PRE_(DEV04_ASC_20260611_181228)".zip


###=== SEND - 0601 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-06-01
php artisan command:SendJournalsDataCommand 2026/06/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_183516_SEND.log
sudo mv storage/app/public/20260601.zip storage/app/public/"20260601_SEND_(DEV04_ASC_20260611_183516)".zip

##=== 06/01 ====================================================================================================##

##=== 07/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0701 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-07-01
php artisan command:DailyRateCalculationPreCommand 2026-07-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P07_PRE.log
sudo mv storage/app/public/20260601_pre.zip storage/app/public/"20260601_PRE_(DEV04_ASC_20260611_P07)".zip


###=== SEND - 0701 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-07-01
php artisan command:SendJournalsDataCommand 2026/07/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S07_SEND.log
sudo mv storage/app/public/20260601.zip storage/app/public/"20260601_SEND_(DEV04_ASC_20260611_S07)".zip

##=== 07/01 ====================================================================================================##

##########################################################################################################################

====================================================================================================

##########################################################################################################################


##=== Logs, Generated Files, & Download links ===###
====================================================================================================

### Move files
========================================================================
###=== 0201 ===### 

sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260201_PRE_(DEV04_ASC_20260611_160132)".zip /home/bizmates/bizmates.jp/public/"20260201_PRE_(DEV04_ASC_20260611_160132)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260201_SEND_(DEV04_ASC_20260611_162621)".zip /home/bizmates/bizmates.jp/public/"20260201_SEND_(DEV04_ASC_20260611_162621)".zip

###=== 0201 ===### 

###-------------------------------------------------------------------------------------###

###=== 0301 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260301_PRE_(DEV04_ASC_20260611_163357)".zip /home/bizmates/bizmates.jp/public/"20260301_PRE_(DEV04_ASC_20260611_163357)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260301_SEND_(DEV04_ASC_20260611_165833)".zip /home/bizmates/bizmates.jp/public/"20260301_SEND_(DEV04_ASC_20260611_165833)".zip


###=== 0301 ===### 

###-------------------------------------------------------------------------------------###

###=== 0401 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260401_PRE_(DEV04_ASC_20260611_170652)".zip /home/bizmates/bizmates.jp/public/"20260401_PRE_(DEV04_ASC_20260611_170652)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260401_SEND_(DEV04_ASC_20260611_173228)".zip /home/bizmates/bizmates.jp/public/"20260401_SEND_(DEV04_ASC_20260611_173228)".zip

###=== 0401 ===### 

###-------------------------------------------------------------------------------------###

###=== 0501 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260501_PRE_(DEV04_ASC_20260611_173954)".zip /home/bizmates/bizmates.jp/public/"20260501_PRE_(DEV04_ASC_20260611_173954)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260501_SEND_(DEV04_ASC_20260611_180514)".zip /home/bizmates/bizmates.jp/public/"20260501_SEND_(DEV04_ASC_20260611_180514)".zip

###=== 0501 ===### 


###-------------------------------------------------------------------------------------###

###=== 0601 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260601_PRE_(DEV04_ASC_20260611_181228)".zip /home/bizmates/bizmates.jp/public/"20260601_PRE_(DEV04_ASC_20260611_181228)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260601_SEND_(DEV04_ASC_20260611_183516)".zip /home/bizmates/bizmates.jp/public/"20260601_SEND_(DEV04_ASC_20260611_183516)".zip

###=== 0601 ===### 

###=== 0701 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260601_PRE_(DEV04_ASC_20260611_P07)".zip /home/bizmates/bizmates.jp/public/"20260601_PRE_(DEV04_ASC_20260611_181228)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260601_SEND_(DEV04_ASC_20260611_S07)".zip /home/bizmates/bizmates.jp/public/"20260601_SEND_(DEV04_ASC_20260611_183516)".zip

###=== 0601 ===### 


##########################################################################################################################


====================================================================================================

## Report Info

Good day, Team!
cc: @Hayato Kuroda-san, @Roi Patrick Florentino-san, @Kenta Miyachi-san

ASC Project Update:
We have successfully rerun the commands on DEV04 for the following execution dates
2026/02/01 captures the January data (2026/01/01 to 2026/01/31).
2026/03/01 captures the February data (2026/02/01 to 2026/02/28).
2026/04/01 captures the March data (2026/03/01 to 2026/03/31).
2026/05/01 captures the April data (2026/04/01 to 2026/04/30).
2026/06/01 captures the May data (2026/05/01 to 2026/05/31).

Below are the links to the files generated during the 2026-06-11 execution:
January data:
https://dev04.dev.bizmates.jp/20260201_PRE_(DEV04_ASC_20260611_160132).zip
https://dev04.dev.bizmates.jp/20260201_SEND_(DEV04_ASC_20260611_162621).zip

February data:
https://dev04.dev.bizmates.jp/20260301_PRE_(DEV04_ASC_20260611_163357).zip
https://dev04.dev.bizmates.jp/20260301_SEND_(DEV04_ASC_20260611_165833).zip

March data:
https://dev04.dev.bizmates.jp/20260401_PRE_(DEV04_ASC_20260611_170652).zip
https://dev04.dev.bizmates.jp/20260401_SEND_(DEV04_ASC_20260611_173228).zip

April data:
https://dev04.dev.bizmates.jp/20260501_PRE_(DEV04_ASC_20260611_173954).zip
https://dev04.dev.bizmates.jp/20260501_SEND_(DEV04_ASC_20260611_180514).zip

May data:
https://dev04.dev.bizmates.jp/20260601_PRE_(DEV04_ASC_20260611_181228).zip
https://dev04.dev.bizmates.jp/20260601_SEND_(DEV04_ASC_20260611_183516).zip


Thank you!







