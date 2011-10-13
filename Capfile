
require 'catpaws'
#generic settings
set :aws_access_key,  ENV['AMAZON_ACCESS_KEY']
set :aws_secret_access_key , ENV['AMAZON_SECRET_ACCESS_KEY']
set :ec2_url, ENV['EC2_URL']
set :ssh_options, { :user => "ubuntu", :keys=>[ENV['EC2_KEYFILE']]}
set :key, ENV['EC2_KEY']
set :key_file, ENV['EC2_KEYFILE']
set :ami, `curl http://mng.iop.kcl.ac.uk/cass_data/buckley_ami/AMIID`.chomp 
set :instance_type, 'm2.4xlarge'
set :working_dir, '/mnt/work'
set :nhosts, 1
set :group_name, 'EscChIPseqAc'
set :snap_id, `cat SNAPID`.chomp 
set :vol_id, `cat VOLUMEID`.chomp 
set :ebs_size, 30 
set :availability_zone, 'eu-west-1a'
set :dev, '/dev/sdh'
#######comment out the sdh line after creating the EC2 and EBS and before mounting###########
#set :dev, '/dev/xvdf'
set :mount_point, '/mnt/data'


# Allow Capfile.local to override these settings
begin
 load("Capfile.local")
rescue Exception
end

#make a new EBS volume from this snap 
#cap EBS:create

#and mount your EBS
#cap EBS:attach
#cap EBS:mount_xfs

#if you want to keep the results

#cap EBS:snapshot


# To load the subprojects, do the following
# cd ns5_h3k4me3_chipseq
# cap EBS:create
# cap EBS:attach
# cap EBS:mount_xfs
# cd ../ns5dastro_h3k4me3_chipseq
# cap EBS:create
# cap EBS:attach
# cap EBS:mount_xfs

# Create a summary of the files
desc "create a summary of the bam files"
task :flagstat, :roles => group_name do
 files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/sorted_nodups\.bam/)}
  files.each{|f|
    f_out = f.sub('.bam', '.summary')
    run "cd #{mount_point} && samtools flagstat #{f} > #{f.out}"
  }

end
before "flagstat", "EC2:start"

task :peak_count, :roles => group_name do

  run "Rscript peak_read_counts.R #{mount_point} 1 /mnt/ns5/ip.export_sorted_nodups.bam /mnt/ns5/macs_300_1.0e-05/ns5_h3k4me3_chipseq_peaks.bed /mnt/ns5dastro/ip.export_mm9_sorted_nodups.bam /mnt/ns5dastro/macs_300_1.0e-05/ns5dastro_h3k4me3_chipseq_peaks.bed"

end
before 'peak_count', 'EC2:start'

# Note - this isn't working yet, the names of the factors are still hard coded in the file.
task :compare_peaks, :roles => group_name do
  run  "Rscript compare_peaks /mnt/data/counts_file.RData /mnt/data/libsizes.RData /mnt/dat"
end
before 'compare_peaks', 'EC2:start'

task :fetch_results, :roles => group_name do
  download("#{mount_point}/peak_compare.csv", "results/peak_compare.csv")
end
before 'fetch_results', 'EC2:start'

#and then shut everything down:

# cap EBS:unmount
# cap EBS:detach
# cap EBS:delete - unless you're planning to use it again.
# cap EC2:stop

rest_ko_input = 'C18_input_CME142_s_7_export_sorted_nodups.bed'
   ctrl_input    = 'CME140_s_5_export_sorted_nodups.bed'

   rest_h3k9ac   = 'CME143_GA3R71_export_sorted_nodups.bed'
   ctrl_h3k9ac   = 'CME141_GA3R71_export_sorted_nodups.bed'

   rest_h4ac     = 'FloResCre__C18__H4ac_CME117_s_2_export_sorted_nodups.bed'
   ctrl_h4ac     = 'FloRes_H4acs_CME118_3_export_sorted_nodups.bed'

    

#Data received on 19/11/10
#-------------------------------------------#
#
#FloResCre (C18) H4ac_CME117_s_2_export.zip
#FloResCre (C18) Input_CME116_s_5_export.zip
#
#FloRes H4acs_CME118_3_export.zip
#
#
#and on 13/01/11
#-------------------------------------------
#
#C18 H3K9ac_CME143_s_8_export.zip
#C18 input_CME142_s_7_export.zip
#
#D4 H3K9ac_CME141_s_6_export.zip
#D4 input_CME140_s_5_export.zip
#
#
#and on 06/04/11
#-------------------------------------------
#
#From Irene's first DVD:
#
#CME141_t1_s_6_export.zip
#CME143_t1_s_8_export.zip
#
#From Irene's second CD, which she thinks is a re-run
#
#CME141_GA3R71_export.zip
#CME143_GA3R71_export.zip



