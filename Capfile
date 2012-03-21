###
# Align the data with Bowtie and dump the resulting BAM files
# on S3
# Run Macs peak finding on them.

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
set :s3cfg, ENV['S3CFG'] #location of ubuntu s3cfg file
set :working_dir, '/mnt/work'
set :availability_zone, 'eu-west-1a'

#note to self
#ami-52794c26 32bit Lucid
#ami-505c6924 64bit Maverick
#ami-20794c54 64bit Lucid

set :nhosts, 1
set :group_name, 'EscChIPseqAc'

set :snap_id, `cat SNAPID`.chomp #ec2 eu-west-1 
set :vol_id, `cat VOLUMEID`.chomp #empty until you've created a new volume
set :ebs_size, 100  #Needs to be the size of the snap plus enough space for alignments
set :ebs_zone, 'eu-west-1a'  #is where the ubuntu ami is
#set :dev, '/dev/sdh'
#######comment out the sdh line after creating the EC2 and EBS and before mounting###########
set :dev, '/dev/xvdh'
set :mount_point, '/mnt/data'

###ssh to server
#ssh -i /home/kkvi1130/ec2/mattskey.pem ubuntu@ec2-79-125-68-105.eu-west-1.compute.amazonaws.com

###sft to server
#sftp -o"IdentityFile=/home/kkvi1130/ec2/mattskey.pem" ubuntu@ec2-79-125-68-105.eu-west-1.compute.amazonaws.com


#make a new EBS volume from this snap 
#cap EBS:create

#and mount your EBS
#cap EBS:attach
#cap EBS:mount_xfs

#### Data uploading.

desc "Upload data files"
task :upload_data, :roles => group_name do
    run "rsync -e 'ssh -i /home/kkvi1130/ec2/mattskey.pem' -vzP data/GFP-TDP43* ubuntu@ec2-46-137-42-36.eu-west-1.compute.amazonaws.com:#{mount_point}" 
end
before 'upload_data', 'EC2:start'

desc "unzip data"
task :unzip_data, :roles => group_name do
    files = capture("ls #{mount_point}/*.gz")
  files = files.split("\n")
  files.each {|f| 
      run "cd #{mount_point}/ && gunzip #{f}"
  }
end
before 'unzip_data', 'EC2:start' 

#### Quality Control

# convert the export.txt file to fastq for alignment
task :make_fastq, :roles => group_name do 
  upload("/space/cassj/chipseq_pipeline/export2fastq.pl", "#{working_dir}/export2fastq.pl")
  run "chmod +x #{working_dir}/export2fastq.pl"
  run "sudo mv #{working_dir}/export2fastq.pl /usr/local/bin/"

  files = capture("ls #{mount_point}/*export.txt").split("\n")
  files = files.map {|f| f.chomp}

  files.each{|infile| 
    outfile = infile.sub('.txt', '.fastq')
    run "export2fastq.pl #{infile} > #{outfile}"
  } 

end
before 'make_fastq', 'EC2:start' 

# Run fastQC on the data files
desc "run fastqc"
task :fastqc, :roles => group_name do
  files = capture("ls #{mount_point}/*.fq").split("\n")
  files = files.map {|f| f.chomp}
   
  files.each{|infile| 
    run "fastqc --outdir #{mount_point} #{infile}"
  } 

end
before 'fastqc', 'EC2:start'

# Pull the results back to the mng.iop.kcl.ac.uk server
desc "download fastqc files"
task :get_fastqc, :roles => group_name do
  `rm -Rf results/fastqc` #remove previous results
  `mkdir -p results/fastqc`
  files = capture "ls #{mount_point}/*fastqc.zip"
  files = files.split("\n")
  files.each{|f|
    outfile = f.sub(/.*\//,'')
    download( "#{f}", "results/fastqc/#{outfile}")
    `cd results/fastqc && unzip #{outfile} && rm #{outfile}`
  }
end
before "get_fastqc", 'EC2:start'

#### Alignment


#get the current human genome from bowtie prebuilt indexes
task :fetch_genome, :roles => group_name do
  run "mkdir -p #{working_dir}/indexes"
  run "cd #{working_dir}/indexes && curl ftp://ftp.cbcb.umd.edu/pub/data/bowtie_indexes/hg19.ebwt.zip > hg19.ebwt.zip"
  run "rm -Rf #{working_dir}/indexes/chr*"
  run "cd  #{working_dir}/indexes && unzip -o hg19.ebwt.zip"
#?  run "export BOWTIE_INDEXES='#{working_dir}/indexes'"
end
before "fetch_genome","EC2:start"

# run bowtie on the fastq file
# This is recent illumina data, quals should be post v1.3
task :run_bowtie, :roles => group_name do

  files = capture("ls #{mount_point}/*.fq").split("\n")
  files = files.map {|f| f.chomp}

  files.each{|infile|
    outfile = infile.sub('.fq', '.sam')
    run("export BOWTIE_INDEXES='#{working_dir}/indexes' && bowtie  --sam --best -k1 -l15 -n1 -m3 -p20 --solexa1.3-quals --chunkmbs 256  -q hg19 --quiet  #{infile}  > #{outfile} ")
  } 

end
before "run_bowtie", "EC2:start"

# Make binary BAM files from SAM
desc "make bam from sam"
task :to_bam, :roles => group_name do
  run "curl 'http://github.com/cassj/my_bioinfo_scripts/raw/master/genomes/hg19_lengths' > #{working_dir}/hg19_lengths"
  files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/\.sam$/)}
  files.each{|f| 
    f_out = f.sub('.sam', '.bam')
    puts "samtools view -bt #{working_dir}/hg19_lengths -o #{mount_point}/#{f_out} #{mount_point}/#{f}"
  }
end
before "to_bam", "EC2:start"

# Sort the BAM files
desc "sort bam"
task :sort_bam, :roles => group_name do
  files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/\.bam/)}
  files.each{|f| 
    f_out = f.sub('.bam', '_sorted')
    puts "cd #{mount_point} && samtools sort #{f}  #{f_out}"
  }
end
before "sort_bam", "EC2:start"


# Remove PCR Duplicate Reads
desc "remove duplicates"
task :rmdups, :roles => group_name do
  files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/sorted\.bam/)}
  files.each{|f| 
    f_out = f.sub('sorted', 'sorted_nodups')
    run "cd #{mount_point} && samtools rmdup -s #{f}  #{f_out}"
  }
end
before "rmdups", "EC2:start"



# Index the BAM files
desc "index bam files"
task :index, :roles => group_name do
  files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/sorted_nodups\.bam/)}
  files.each{|f| 
    f_out = f.sub('.bam', '.bai')
    run "cd #{mount_point} && samtools index  #{f} #{f_out}"
  }
end
before "index", "EC2:start"

# Create a summary of the files
desc "create a summary of the bam files"
task :flagstat, :roles => group_name do
 files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/sorted_nodups\.bam/)}
  files.each{|f|
    f_out = f.sub('.bam', '.summary')
    run "cd #{mount_point} && samtools flagstat #{f} > #{f_out}"
  }

end
before "flagstat", "EC2:start"


# Pull the BAM files back to the mng.iop.kcl.ac.uk server
desc "download bam files"
task :get_bam, :roles => group_name do
  `rm -Rf results/alignment/bowtie` #remove previous results
  `mkdir -p results/alignment/bowtie`
  files = capture "ls #{mount_point}"
  files = files.split("\n").select{|f| f.match(/sorted_nodups/)}
  files.each{|f|
    download( "#{mount_point}/#{f}", "results/alignment/bowtie/#{f}")
  }
end
before "get_bam","EBS:snapshot","EC2:start"



### Macs ?

#macs_url ="http://liulab.dfci.harvard.edu/MACS/src/MACS-1.4.0beta.tar.gz"
#macs_version = "MACS-1.4.0beta"
#
#task :install_macs, :roles => group_name do
#  sudo "apt-get install -y python"
#  run "cd #{working_dir} && wget --http-user macs --http-passwd chipseq #{macs_url}"
#  run "cd #{working_dir} && tar -xvzf #{macs_version}.tar.gz"
#  run "cd #{working_dir}/#{macs_version} && sudo python setup.py install"
#  sudo "ln -s /usr/local/bin/macs* /usr/local/bin/macs"
#end
#before "install_macs", 'EC2:start'
#
#task :install_peaksplitter, :roles => group_name do
#  url ='http://www.ebi.ac.uk/bertone/software/PeakSplitter_Cpp_1.0.tar.gz'
#  filename = 'PeakSplitter_Cpp_1.0.tar.gz'
#  bin = 'PeakSplitter_Cpp/PeakSplitter_Linux64/PeakSplitter'
#  run "cd #{working_dir} && curl #{url} > #{filename}"
#  run "cd #{working_dir} && tar -xvzf #{filename}"
#  run "sudo cp #{working_dir}/#{bin} /usr/local/bin/PeakSplitter"
#end 
#before 'install_peaksplitter', 'EC2:start'

desc "run macs"
task :run_macs, :roles => group_name do
  HA-FUS_standard_IP = "#{mount_point}/HA-FUS_w6_standard_ChIP_clean_sorted_nodups.bam"
  HA-FUS_2step_IP = "#{mount_point}/HA-FUS_w6_2steps_fix_ChIP_clean_sorted_nodups.bam"
  GFP-TDP43_standard_IP = "#{mount_point}/GFP-TDP43_w4_standard_ChIP_input_clean_sorted_nodups.bam"
  GFP-TFP43_2step_IP = "#{mount_point}/GFP-TDP43_w4_2steps_fix_ChIP_clean_sorted_nodups.bam"
  Input_2steps = "#{mount_point}/HA-FUS_w6_2steps_fix_ChIP_input_clean_sorted_nodups.bam"
  Input_standard = "#{mount_point}/GFP-TDP43_w4_standard_ChIP_input_clean_sorted_nodups.bam"

  genome = 'hs'
  bws = [300]
  pvalues = [0.00001]

      dir = "#{mount_point}/macs_#{bw}_#{pvalue}_HA_FUS_standard"
      run "rm -Rf #{dir}"
      run "mkdir #{dir}"

      macs_cmd =  "macs --treatment #{HA-FUS_standard_IP} --control #{Input_standard} --name #{group_name} --format BAM --gsize #{genome} --pvalue #{pvalue}"
      run "cd #{dir} && #{macs_cmd}"

      dir = "#{mount_point}/macs_#{bw}_#{pvalue}_HA_FUS_2step"
      run "rm -Rf #{dir}"
      run "mkdir #{dir}"

      macs_cmd =  "macs --treatment #{HA-FUS_2step_IP} --control #{Input_2steps} --name #{group_name} --format BAM --gsize #{genome} --pvalue #{pvalue}"
      run "cd #{dir} && #{macs_cmd}"

      dir = "#{mount_point}/macs_#{bw}_#{pvalue}_GFP-TDP43_standard"
      run "rm -Rf #{dir}"
      run "mkdir #{dir}"

      macs_cmd =  "macs --treatment #{GFP-TDP43_standard_IP} --control #{Input_standard} --name #{group_name} --format BAM --gsize #{genome} --pvalue #{pvalue}"
      run "cd #{dir} && #{macs_cmd}"

      dir = "#{mount_point}/macs_#{bw}_#{pvalue}_GFP-TDP43_2step"
      run "rm -Rf #{dir}"
      run "mkdir #{dir}"

      macs_cmd =  "macs --treatment #{GFP-TFP43_2step_IP} --control #{Input_2steps} --name #{group_name} --format BAM --gsize #{genome} --pvalue #{pvalue}"
      run "cd #{dir} && #{macs_cmd}"      
     

    
  
end
before 'run_macs', 'EC2:start'


desc "bamToBed"
task :bamToBed, :roles => group_name do
   files = capture("ls #{mount_point}/*sorted_nodups.bam").split("\n")
   files = files.map {|f| f.chomp}
   files.each{|infile|
     f_out = infile.sub('.bam', '.bed')
     run "bamToBed -i #{infile} > #{f_out}"
   }

end
before 'bamToBed', 'EC2:start'

####run SICER
desc "run SICER"
task :run_SICER, :roles => group_name do

   rest_ko_input = 'C18_input_CME142_s_7_export_sorted_nodups.bed'
   ctrl_input    = 'CME140_s_5_export_sorted_nodups.bed'

   rest_h3k9ac   = 'CME143_GA3R71_export_sorted_nodups.bed'
   ctrl_h3k9ac   = 'CME141_GA3R71_export_sorted_nodups.bed'

   rest_h4ac     = 'FloResCre__C18__H4ac_CME117_s_2_export_sorted_nodups.bed'
   ctrl_h4ac     = 'FloRes_H4acs_CME118_3_export_sorted_nodups.bed'
   

   species = 'mm9'
   thresh = 1
   window_size = 200
   fragment_size = 300
   effective_genome_fraction = '0.75' 
   gap_size = 600
   FDR = '0.001'

# /usr/local/bin/SICER [InputDir] [bed file] [control file] [OutputDir] [Species] [redundancy threshold] [window size (bp)] [fragment size] [effective genome fraction] [gap size (bp)] [FDR]

 #  run "mkdir -p #{mount_point}/SICER"


 #  run "mkdir -p #{mount_point}/SICER/rest_h3k9ac"
 #  run "cd #{mount_point}/SICER/rest_h3k9ac"
 #  run "SICER #{mount_point} #{rest_h3k9ac} #{rest_ko_input} #{mount_point}/SICER/rest_h3k9ac #{species} #{thresh} #{window_size} #{fragment_size} #{effective_genome_fraction} #{gap_size} #{FDR}"

 #  run "mkdir -p #{mount_point}/SICER/rest_h4ac"
 #  puts "cd #{mount_point}/SICER/rest_h4ac && SICER #{mount_point} #{rest_h4ac} #{rest_ko_input} #{mount_point}/SICER/rest_h4ac #{species} #{thresh} #{window_size} #{fragment_size} #{effective_genome_fraction} #{gap_size} #{FDR}"


#   run "mkdir -p #{mount_point}/SICER/ctrl_h3k9ac"
  puts "cd #{mount_point}/SICER/ctrl_h3k9ac && SICER #{mount_point} #{ctrl_h3k9ac} #{ctrl_input} #{mount_point}/SICER/ctrl_h3k9ac #{species} #{thresh} #{window_size} #{fragment_size} #{effective_genome_fraction} #{gap_size} #{FDR}"
#
#   run "mkdir -p #{mount_point}/SICER/ctrl_h4ac"
#   puts "cd #{mount_point}/SICER/ctrl_h4ac && SICER #{mount_point} #{ctrl_h4ac} #{ctrl_input} #{mount_point}/SICER/ctrl_h4ac #{species} #{thresh} #{window_size} #{fragment_size} #{effective_genome_fraction} #{gap_size} #{FDR}"
#

end
before 'run_SICER', 'EC2:start'

#SICER /mnt/data CME141_GA3R71_export_sorted_nodups.bed CME140_s_5_export_sorted_nodups.bed /mnt/data/SICER/ctrl_h3k9ac mm9 1 200 300 0.75 600 0.001



#pack up the runs and downloads them to the server (without the wig files)
task :pack_macs, :roles => group_name do
  macs_dirs = capture "ls #{mount_point}"
  macs_dirs = macs_dirs.split("\n").select {|f| f.match(/.*macs.*/)}
  macs_dirs.each{|d|
    run "cd #{mount_point} &&  tar --exclude *_wiggle* -cvzf #{d}.tgz #{d}"
  }
  
end
before 'pack_macs','EC2:start' 

task :get_macs, :roles => group_name do
  macs_files = capture "ls #{mount_point}"
  macs_files = macs_files.split("\n").select {|f| f.match(/.*macs.*\.tgz/)}
  res_dir = 'results/alignment/bowtie/peakfinding/macs'
  `rm -Rf #{res_dir}`
  `mkdir -p #{res_dir}`
  macs_files.each{|f| 
    download("#{mount_point}/#{f}", "#{res_dir}/#{f}") 
    `cd #{res_dir} && tar -xvzf #{f}`
  }

end
before 'get_macs', 'EC2:start'






#if you want to keep the results

#cap EBS:snapshot


#and then shut everything down:

# cap EBS:unmount
# cap EBS:detach
# cap EBS:delete - unless you're planning to use it again.
# cap EC2:stop




