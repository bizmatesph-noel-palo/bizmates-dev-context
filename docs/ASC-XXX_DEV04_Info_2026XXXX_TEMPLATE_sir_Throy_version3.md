
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
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'accessToken','XXX',now(),now());
INSERT INTO mst_admin_setting (description, item_name, item_value, created_at, updated_at) VALUES('ASC Project', 'refreshToken','XXX',now(),now());



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
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P02_PRE.log
sudo mv storage/app/public/20260201_pre.zip storage/app/public/"20260201_PRE_(DEV04_ASC_20260611_P02)".zip

###=== SEND - 0201 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-02-01
php artisan command:SendJournalsDataCommand 2026/02/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S02_SEND.log
sudo mv storage/app/public/20260201.zip storage/app/public/"20260201_SEND_(DEV04_ASC_20260611_S02)".zip

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
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P03_PRE.log
sudo mv storage/app/public/20260301_pre.zip storage/app/public/"20260301_PRE_(DEV04_ASC_20260611_P03)".zip

###=== SEND - 0301 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-03-01
php artisan command:SendJournalsDataCommand 2026/03/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S03_SEND.log
sudo mv storage/app/public/20260301.zip storage/app/public/"20260301_SEND_(DEV04_ASC_20260611_S03)".zip

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
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P04_PRE.log
sudo mv storage/app/public/20260401_pre.zip storage/app/public/"20260401_PRE_(DEV04_ASC_20260611_P04)".zip

###=== SEND - 0401 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-04-01
php artisan command:SendJournalsDataCommand 2026/04/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S04_SEND.log
sudo mv storage/app/public/20260401.zip storage/app/public/"20260401_SEND_(DEV04_ASC_20260611_S04)".zip

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
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P05_PRE.log
sudo mv storage/app/public/20260501_pre.zip storage/app/public/"20260501_PRE_(DEV04_ASC_20260611_P05)".zip

###=== SEND - 0501 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-05-01
php artisan command:SendJournalsDataCommand 2026/05/01


# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S05_SEND.log
sudo mv storage/app/public/20260501.zip storage/app/public/"20260501_SEND_(DEV04_ASC_20260611_S05)".zip

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
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P06_PRE.log
sudo mv storage/app/public/20260601_pre.zip storage/app/public/"20260601_PRE_(DEV04_ASC_20260611_P06)".zip


###=== SEND - 0601 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-06-01
php artisan command:SendJournalsDataCommand 2026/06/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S06_SEND.log
sudo mv storage/app/public/20260601.zip storage/app/public/"20260601_SEND_(DEV04_ASC_20260611_S06)".zip

##=== 06/01 ====================================================================================================##

##########################################################################################################################

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
sudo mv storage/app/public/20260701_pre.zip storage/app/public/"20260701_PRE_(DEV04_ASC_20260611_P07)".zip

###=== SEND - 0701 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-07-01
php artisan command:SendJournalsDataCommand 2026/07/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S07_SEND.log
sudo mv storage/app/public/20260701.zip storage/app/public/"20260701_SEND_(DEV04_ASC_20260611_S07)".zip

##=== 07/01 ====================================================================================================##

##########################################################################################################################

##=== 08/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0801 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-08-01
php artisan command:DailyRateCalculationPreCommand 2026-08-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P08_PRE.log
sudo mv storage/app/public/20260801_pre.zip storage/app/public/"20260801_PRE_(DEV04_ASC_20260611_P08)".zip

###=== SEND - 0801 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-08-01
php artisan command:SendJournalsDataCommand 2026/08/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S08_SEND.log
sudo mv storage/app/public/20260801.zip storage/app/public/"20260801_SEND_(DEV04_ASC_20260611_S08)".zip

##=== 08/01 ====================================================================================================##

##########################################################################################################################

##=== 09/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 0901 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-09-01
php artisan command:DailyRateCalculationPreCommand 2026-09-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P09_PRE.log
sudo mv storage/app/public/20260901_pre.zip storage/app/public/"20260901_PRE_(DEV04_ASC_20260611_P09)".zip

###=== SEND - 0901 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-09-01
php artisan command:SendJournalsDataCommand 2026/09/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S09_SEND.log
sudo mv storage/app/public/20260901.zip storage/app/public/"20260901_SEND_(DEV04_ASC_20260611_S09)".zip

##=== 09/01 ====================================================================================================##

##########################################################################################################################

##=== 10/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 1001 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-10-01
php artisan command:DailyRateCalculationPreCommand 2026-10-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P10_PRE.log
sudo mv storage/app/public/20261001_pre.zip storage/app/public/"20261001_PRE_(DEV04_ASC_20260611_P10)".zip

###=== SEND - 1001 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-10-01
php artisan command:SendJournalsDataCommand 2026/10/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S10_SEND.log
sudo mv storage/app/public/20261001.zip storage/app/public/"20261001_SEND_(DEV04_ASC_20260611_S10)".zip

##=== 10/01 ====================================================================================================##

##########################################################################################################################

##=== 11/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 1101 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-11-01
php artisan command:DailyRateCalculationPreCommand 2026-11-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P11_PRE.log
sudo mv storage/app/public/20261101_pre.zip storage/app/public/"20261101_PRE_(DEV04_ASC_20260611_P11)".zip

###=== SEND - 1101 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-11-01
php artisan command:SendJournalsDataCommand 2026/11/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S11_SEND.log
sudo mv storage/app/public/20261101.zip storage/app/public/"20261101_SEND_(DEV04_ASC_20260611_S11)".zip

##=== 11/01 ====================================================================================================##

##########################################################################################################################

##=== 12/01 ====================================================================================================##

# ASC Files & Logs
====================================================================================================
tail storage/logs/laravel.log
ls -la storage/logs
ls -la storage/app/public
====================================================================================================

###=== PRE - 1201 ===###
========================================================================
php artisan command:MonthlyRateCalculationPreCommand 2026-12-01
php artisan command:DailyRateCalculationPreCommand 2026-12-01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_P12_PRE.log
sudo mv storage/app/public/20261201_pre.zip storage/app/public/"20261201_PRE_(DEV04_ASC_20260611_P12)".zip

###=== SEND - 1201 ===###
========================================================================
php artisan command:MonthlyRateCalculationCommand 2026-12-01
php artisan command:SendJournalsDataCommand 2026/12/01

# Rename log and zip file #
===========================
sudo mv storage/logs/laravel.log storage/logs/laravel_DEV04_ASC_20260611_S12_SEND.log
sudo mv storage/app/public/20261201.zip storage/app/public/"20261201_SEND_(DEV04_ASC_20260611_S12)".zip

##=== 12/01 ====================================================================================================##

##########################################################################################################################

====================================================================================================

##########################################################################################################################


##=== Logs, Generated Files, & Download links ===###
====================================================================================================

### Move files
========================================================================
###=== 0201 ===### 

sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260201_PRE_(DEV04_ASC_20260611_P02)".zip /home/bizmates/bizmates.jp/public/"20260201_PRE_(DEV04_ASC_20260611_P02)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260201_SEND_(DEV04_ASC_20260611_S02)".zip /home/bizmates/bizmates.jp/public/"20260201_SEND_(DEV04_ASC_20260611_S02)".zip

###=== 0201 ===### 

###-------------------------------------------------------------------------------------###

###=== 0301 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260301_PRE_(DEV04_ASC_20260611_P03)".zip /home/bizmates/bizmates.jp/public/"20260301_PRE_(DEV04_ASC_20260611_P03)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260301_SEND_(DEV04_ASC_20260611_S03)".zip /home/bizmates/bizmates.jp/public/"20260301_SEND_(DEV04_ASC_20260611_S03)".zip


###=== 0301 ===### 

###-------------------------------------------------------------------------------------###

###=== 0401 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260401_PRE_(DEV04_ASC_20260611_P04)".zip /home/bizmates/bizmates.jp/public/"20260401_PRE_(DEV04_ASC_20260611_P04)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260401_SEND_(DEV04_ASC_20260611_S04)".zip /home/bizmates/bizmates.jp/public/"20260401_SEND_(DEV04_ASC_20260611_S04)".zip

###=== 0401 ===### 

###-------------------------------------------------------------------------------------###

###=== 0501 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260501_PRE_(DEV04_ASC_20260611_P05)".zip /home/bizmates/bizmates.jp/public/"20260501_PRE_(DEV04_ASC_20260611_P05)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260501_SEND_(DEV04_ASC_20260611_S05)".zip /home/bizmates/bizmates.jp/public/"20260501_SEND_(DEV04_ASC_20260611_S05)".zip

###=== 0501 ===### 


###-------------------------------------------------------------------------------------###

###=== 0601 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260601_PRE_(DEV04_ASC_20260611_P06)".zip /home/bizmates/bizmates.jp/public/"20260601_PRE_(DEV04_ASC_20260611_P06)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260601_SEND_(DEV04_ASC_20260611_S06)".zip /home/bizmates/bizmates.jp/public/"20260601_SEND_(DEV04_ASC_20260611_S06)".zip

###=== 0601 ===### 

###-------------------------------------------------------------------------------------###

###=== 0701 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260701_PRE_(DEV04_ASC_20260611_P07)".zip /home/bizmates/bizmates.jp/public/"20260701_PRE_(DEV04_ASC_20260611_P07)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260701_SEND_(DEV04_ASC_20260611_S07)".zip /home/bizmates/bizmates.jp/public/"20260701_SEND_(DEV04_ASC_20260611_S07)".zip

###=== 0701 ===### 

###-------------------------------------------------------------------------------------###

###=== 0801 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260801_PRE_(DEV04_ASC_20260611_P08)".zip /home/bizmates/bizmates.jp/public/"20260801_PRE_(DEV04_ASC_20260611_P08)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260801_SEND_(DEV04_ASC_20260611_S08)".zip /home/bizmates/bizmates.jp/public/"20260801_SEND_(DEV04_ASC_20260611_S08)".zip

###=== 0801 ===### 

###-------------------------------------------------------------------------------------###

###=== 0901 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260901_PRE_(DEV04_ASC_20260611_P09)".zip /home/bizmates/bizmates.jp/public/"20260901_PRE_(DEV04_ASC_20260611_P09)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20260901_SEND_(DEV04_ASC_20260611_S09)".zip /home/bizmates/bizmates.jp/public/"20260901_SEND_(DEV04_ASC_20260611_S09)".zip

###=== 0901 ===### 

###-------------------------------------------------------------------------------------###

###=== 1001 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20261001_PRE_(DEV04_ASC_20260611_P10)".zip /home/bizmates/bizmates.jp/public/"20261001_PRE_(DEV04_ASC_20260611_P10)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20261001_SEND_(DEV04_ASC_20260611_S10)".zip /home/bizmates/bizmates.jp/public/"20261001_SEND_(DEV04_ASC_20260611_S10)".zip

###=== 1001 ===### 

###-------------------------------------------------------------------------------------###

###=== 1101 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20261101_PRE_(DEV04_ASC_20260611_P11)".zip /home/bizmates/bizmates.jp/public/"20261101_PRE_(DEV04_ASC_20260611_P11)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20261101_SEND_(DEV04_ASC_20260611_S11)".zip /home/bizmates/bizmates.jp/public/"20261101_SEND_(DEV04_ASC_20260611_S11)".zip

###=== 1101 ===### 

###-------------------------------------------------------------------------------------###

###=== 1201 ===### 
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20261201_PRE_(DEV04_ASC_20260611_P12)".zip /home/bizmates/bizmates.jp/public/"20261201_PRE_(DEV04_ASC_20260611_P12)".zip
sudo cp /home/bizmates/accounting_related_system_for_freee/storage/app/public/"20261201_SEND_(DEV04_ASC_20260611_S12)".zip /home/bizmates/bizmates.jp/public/"20261201_SEND_(DEV04_ASC_20260611_S12)".zip

###=== 1201 ===### 


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
2026/07/01 captures the June data (2026/06/01 to 2026/06/30).
2026/08/01 captures the July data (2026/07/01 to 2026/07/31).
2026/09/01 captures the August data (2026/08/01 to 2026/08/31).
2026/10/01 captures the September data (2026/09/01 to 2026/09/30).
2026/11/01 captures the October data (2026/10/01 to 2026/10/31).
2026/12/01 captures the November data (2026/11/01 to 2026/11/30).

Below are the links to the files generated during the 2026-06-11 execution:
January data:
https://dev04.dev.bizmates.jp/20260201_PRE_(DEV04_ASC_20260611_P02).zip
https://dev04.dev.bizmates.jp/20260201_SEND_(DEV04_ASC_20260611_S02).zip

February data:
https://dev04.dev.bizmates.jp/20260301_PRE_(DEV04_ASC_20260611_P03).zip
https://dev04.dev.bizmates.jp/20260301_SEND_(DEV04_ASC_20260611_S03).zip

March data:
https://dev04.dev.bizmates.jp/20260401_PRE_(DEV04_ASC_20260611_P04).zip
https://dev04.dev.bizmates.jp/20260401_SEND_(DEV04_ASC_20260611_S04).zip

April data:
https://dev04.dev.bizmates.jp/20260501_PRE_(DEV04_ASC_20260611_P05).zip
https://dev04.dev.bizmates.jp/20260501_SEND_(DEV04_ASC_20260611_S05).zip

May data:
https://dev04.dev.bizmates.jp/20260601_PRE_(DEV04_ASC_20260611_P06).zip
https://dev04.dev.bizmates.jp/20260601_SEND_(DEV04_ASC_20260611_S06).zip

June data:
https://dev04.dev.bizmates.jp/20260701_PRE_(DEV04_ASC_20260611_P07).zip
https://dev04.dev.bizmates.jp/20260701_SEND_(DEV04_ASC_20260611_S07).zip

July data:
https://dev04.dev.bizmates.jp/20260801_PRE_(DEV04_ASC_20260611_P08).zip
https://dev04.dev.bizmates.jp/20260801_SEND_(DEV04_ASC_20260611_S08).zip

August data:
https://dev04.dev.bizmates.jp/20260901_PRE_(DEV04_ASC_20260611_P09).zip
https://dev04.dev.bizmates.jp/20260901_SEND_(DEV04_ASC_20260611_S09).zip

September data:
https://dev04.dev.bizmates.jp/20261001_PRE_(DEV04_ASC_20260611_P10).zip
https://dev04.dev.bizmates.jp/20261001_SEND_(DEV04_ASC_20260611_S10).zip

October data:
https://dev04.dev.bizmates.jp/20261101_PRE_(DEV04_ASC_20260611_P11).zip
https://dev04.dev.bizmates.jp/20261101_SEND_(DEV04_ASC_20260611_S11).zip

November data:
https://dev04.dev.bizmates.jp/20261201_PRE_(DEV04_ASC_20260611_P12).zip
https://dev04.dev.bizmates.jp/20261201_SEND_(DEV04_ASC_20260611_S12).zip


Thank you!
