-- SQL语言一共分为4大类：
-- 1，数据定义语言DDL(Data Definition Language),
--    操作对象为：数据库和表，
--    关键词create(建表和数据库),drop(删除表),alter(更改表),truncate(清空表),use(切换数据库),show(显示数据库,表信息)，desc(查看表结构)
-- 2，数据操纵语言DML(Data Manipulatin Language)
--    操作对象为：行记录
--    关键词insert(插入记录),update(更新记录),delete(删除记录)
--    hive中支持load(载入数据记录,可以选择是否overwrite),insert overwrite table xx_table select **
-- 3，数据查询语言DQL(Data Query Language)
--    select ... from 小表 join 大表 on 等值连接 where 分组前过滤条件 group by 分组字段 having 分组后过滤条件 order by 排序字段
--    执行顺序：join-->from->where->group by->having->order by->select
-- 4，数据控制语言DCL(Data Control Language)
--    用户，权限，事务


-- 〇, 执行hivesql的几种方式
hive -e  'select 100'
hive -f  test.sql  --执行sql文件后退出
hive -i  test.sql  --执行sql文件后不退出，进入sql命令行
hive > source test.sql  --在sql命令行中执行sql文件
hive > !ls     --在sql命令行中执行linux命令需要加！

-- 一, 查看表信息和帮助信息
desc formatted tj_tmp.ly_sample;   --查看表结构
show create table tj_tmp.ly_sample; --可以查看table在hdfs上的存储路径
show functions; --查看当前可用的函数名
desc function concat; --查看concat函数的帮助信息


-- 二，建表并载入数据
drop table if exists tj_tmp.ly_sample;
create table if not exists  tj_tmp.ly_sample 
(name string comment '姓名',
 idcard string comment '身份证',
 phone string comment '手机号',
 loan_dt date comment '贷款时间')
comment '样本表'
row format delimited
fields terminated by '\001'
collection items terminated by '\002' 
map keys terminated by '\003'
lines terminated by '\n'
stored as textfile;

--从本地载入数据到表格
load data local inpath 'sample.txt' (overwrite) into table tj_tmp.ly_sample;
--从集群载入数据到表格
load data inpath 'sample' (overwrite) into table tj_tmp.ly_sample;


--通过重新建表更换分隔符示范
drop table if exists tj_tmp.ly_app_install;
create table tj_tmp.ly_app_install 
row format delimited
fields terminated by '\001'
collection items terminated by '\002' 
map keys terminated by '\003'
lines terminated by '\n'
stored as textfile
as 
select a.mbl_num as phone,
a.iden_num as idcard,
a.create_dt as create_dt,
a.update_dt as update_dt,
a.applist as applist
from 
tj_base.app_install_list_from_tjy_v01 as a
limit 10 


-- 三,查询表并导出数据

--/*
--insert overwrite local directory './testdata'   --导入到本地
--insert overwrite directory '/user/hive/warehouse/tj_tmp.db/liangyun/bussiness'  --导入到hdfs目录
--row format delimited fields terminated by '\t' --指定分割符号
--create table tj_test.lytest as --在tj_test 创建新表lytest
--*/
drop table if exists tj_test.ly_loan_orders;
create table tj_test.ly_loan_orders as
select loan_id,
user_name as name,
user_mbl_num as phone,
loan_dt, 
loan_term as apply_term,
loan_amt as apply_amount, 
nvl(max(curr_overdue_days),-1) as overduedays,
'2018-06-11' as get_data_dt
from rtj.success_loan_orders
where
user_cur_id > 0
and product_name rlike '.*(极速贷|支付贷).*' 
and product_name not like '%老用户%'
and loan_amt >=3000 and loan_amt<=5000
and loan_term >=3 
and loan_dt >= '2018-01-01' and loan_dt < '2018-05-10' 
and etl_dt >= '2018-01-01' 
and etl_dt <= date_add(add_months(loan_dt,cast(loan_term as int)),40)
group by loan_id,user_name,user_mbl_num,loan_dt,loan_term,loan_amt

-- 多表插入
from mydb.employee
insert into table test
select id, name, telephone, age
insert into table test3
select id, name
where age>25;


--四，创建视图
create view if not exists emp_30000 as
select * from employee
where salary>30000;

--删除视图
drop view emp_30000

-- 五，常用函数

--日期函数：date_add,add_months,datediff
--格式转换：cast
--字符串拼接：concat,concat_ws
--字符串截取：substr('abc23',0,3)返回 'abc'
--收集列数据：collect_list,collect_set 为聚合函数
--处理空值：nvl(expr1,expr2) 若expr1为空，返回expr2


-- 六, 排序
--排序可以是 order by全局排序（效率较低）和 sort by 在 reducer端局部排序（效率较高）
--以及 cluster by （等价于 distributed by 再 sort by,只能降序）
--destributed by 分桶

--全局排序
select name,class,age from students order by age desc
--先分桶再排序,局部排序
select name,class,age from students distribute by class sort by class asc,age desc
--cluster排序，局部排序
select name,class,age from students cluster by class 
--全局排序的优化 
select * from (select name,class,age from students distribute by class sort by age desc) as t order by t.age desc;


-- 七,分区表

-- 创建分区表

create external table if not exists mydb.employee(
id int,
name string,
job string,
month string
)

partitioned by (month string)
row format delimited fields terminated by '\t'

-- 还可以添加二级分区
-- 相当于创建2个文件夹，在month下创建了day文件夹
-- day文件下就是具体的文件
partitioned by (month string,day string)

-- 加载数据到指定分区
load data local inpath '/opt/datas/emp.txt' into table mydb.employee partition (month='201803');

-- 加载数据到动态分区
set hive.exec.dynamic.partition.mode=nonstrict; -- 启用动态分区
insert into table test
    partition (month)
    select id, name,job,month
    from mydb.employee;

-- 查询201803分区数据
select * from employee where month='201803' ;


-- 八，hive传参

--hive通过定义变量来传参，有hive -d x=100 -f xx.sql 和 hive> set x=100两种方式。
--hive的变量前面有一个命名空间，包括hiveconf、system、env，还有一个hivevar。
--1.hiveconf的命名空间指的是hive-site.xml下面的配置变量值。
--2.system的命名空间是系统的变量，包括JVM的运行环境。
--3.env的命名空间，是指环境变量，包括Shell环境下的变量信息，如HIVE_HOME之类的。
--4.使用 hive -d x = 100 定义的变量其命名空间都是 hivevar可以用${hivevar:变量名}，hivevar可以省略。
--  也可以使用hive --define key=value或者是hive --hivevar key=value来声明，这都代表是hivevar的变量。
--5.在linux hive交互环境下用set定义的变量命名空间都是hiveconf,可以用${hiveconf:变量名}引用，hiveconf不可省略。

hive -d shell_date_1='20120425' -d shell_date_2='20120426'
hive -d start_date ='2018-01-01' -d end_date = '2018-05-01' -f hive.sql

hive> set shell_date_1 = '20120425';
hive> explain select * from dual where user_id = ${hiveconf:shell_date_1};
hive> select * from dual where user_id = ${hiveconf:shell_date_1};




-- 九, hive开窗函数  over(partition by ......)

-- 开窗函数over(partition by ......)主要和聚合函数sum()、count()、avg()、rank()、row_number()等结合使用，实现分组聚合的功能
-- 带上group by的hive sql语句只能显示与分组聚合相关的字段，而带上over(partition by ......)的hive sql语句能显示所有字段

select id,
name,
department,
salary,
rank() over (partition by department order by salary desc ) rp, -- 排名函数，相同值排名有重复，结果如：1,2,2,4,5
dense_rank() over(partition by departmente order by salary desc ) drp,  -- 排名函数，相同值排名有重复，结果如： 1,2,2,3,4
row_number()over(partition by department order by salary desc) rmp,   -- 排名函数，无重复，结果如：1,2,3,4,5
NTILE(2) over(partition by name order by salary desc ) rn， -- 分箱切片函数，返回属于的梯度次序
count(*) over(partition by department)  group_number
from employee
where  rn == 1  -- 仅取前一半员工



-- 十,hive中执行map reduce脚本

-- 示范1
add file weekday_mapper.py
select
  transform (user_id, movie_id, rating, strdate)
  using 'python weekday_mapper.py'
  as (user_id, movie_id, rating, weekday)
from tj_tmp.ly_u_data;

-- weeekday_mapper.py内容如下：

from __future__ import print_function
import sys
import datetime

for line in sys.stdin:
  line = line.strip()
  userid, movieid, rating, strdate = line.split('\t')
  weekday = datetime.datetime.strptime(strdate,'%Y-%m-%d').weekday()
  print ('\t'.join([userid, movieid, rating, str(weekday)]))
   
-- 示范2
-- 注：map和reduce只是transform的别名，用map不一定会启用map过程，
-- 用reduce不一定会启用reduce过程，cluster by负责给reducer分桶。

from(  
map doctext using 'python wc_mapper.py' as (word, cnt)  
from docs  
cluster by word  
) a  
reduce word, cnt using 'python wc_reduce.py'; 












