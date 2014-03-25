require_relative '../test_helper'

class ParsingTest < ActiveSupport::TestCase
  context "parser" do
    setup do
      stub_solr
      Snp.delete_all
      UserSnp.delete_all
      Genotype.delete_all

      @file_23andMe = "#{Rails.root}/test/data/23andMe_test.csv"
      Sidekiq::Client.stubs(:enqueue).with(Preparsing, instance_of(Fixnum))
      @genotype_23andme = FactoryGirl.create(:genotype,
        genotype_file_name: @file_23andMe.split('/').last, filetype: '23andme',
        md5sum: '820f0bd9fda947860859260a7b9b12d3', genotype_content_type: 'text/plain',
        genotype_updated_at: '2014-03-18 06:58:00' , genotype_file_size: 1012)
                                            

      @file_deCODEme = "#{Rails.root}/test/data/deCODEme_test.csv"
      @genotype_decodeme = FactoryGirl.create(:genotype,
        genotype_file_name: @file_deCODEme.split('/').last, filetype: 'decodeme', 
        md5sum: '7e3ed88e811da812ffbbb406c0376ebf', genotype_content_type: 'text/plain',
        genotype_updated_at: '2014-03-18 06:58:00' , genotype_file_size: 197)

      @temp_file = "#{Rails.root}/tmp/snp_file.txt"
      FileUtils.rm(@temp_file) if File.exist?(@temp_file)
    end

    should "parse 23andMe data" do
      FileUtils.cp @file_23andMe, @temp_file
      Parsing.new.perform(@genotype_23andme.id, @temp_file)
      
      # paranoia test - do the genotypes even exist?
      genotypes = Genotype.all.map do |g|
        [ g.id ]
      end.sort_by { |g| g[0] }

      expected = [ [5], [6] ] 

      assert_equal expected, genotypes

      # Snp
      snp_data = Snp.all.map do |s|
        [ s.name, s.position, s.chromosome, s.genotype_frequency, s.allele_frequency, s.ranking, s.user_snps_count ]
      end.sort_by { |s| s[0] }

      expected =
        [ [ "rs11240777", "788822", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1 ],
          [ "rs12124819", "766409", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1 ],
          [ "rs3094315",  "742429", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1 ],
          [ "rs3131972",  "742584", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1 ],
          [ "rs4477212",  "72017",  "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1 ]]

      assert_equal expected, snp_data

      # UserSnp
      user_snps = UserSnp.all
      user_snp_genotypes = user_snps.map(&:local_genotype)
      expected_genotypes = %w[ AA AA GG AG AG ]
      assert_equal expected_genotypes, user_snp_genotypes
      user_snps.each do |s|
        assert_equal @genotype_23andme.id, s.genotype_id
        assert_equal @genotype_23andme.user.id, s.user_id
        assert Snp.pluck(:name).include?(s.snp_name)
      end
    end

    # could put these deleting tests into their own file;
    # however, the genotyping exists at this point in time and we don't have to do any extra work
    # to pull it from the test DB
    should "delete 23andMe data" do
      DeleteGenotype.new.perform(@genotype_23andme)

      expected = 0
      number_of_snps = Snp.all.count

      assert_equal expected, number_of_snps
    end

    should "parse deCODEme data" do
      FileUtils.cp @file_deCODEme, @temp_file
      Parsing.new.perform(@genotype_decodeme.id, @temp_file)

      # Genotypes
      genotypes = Genotype.all.map do |g|
        [ g.id ]
      end.sort_by { |g| g[0] }

      expected = [ [7], [8] ] 

      assert_equal expected, genotypes


      # Snp
      snp_data = Snp.all.map do |s|
        [ s.name, s.position, s.chromosome, s.genotype_frequency, s.allele_frequency, s.ranking, s.user_snps_count ]
      end.sort_by { |s| s[0] }

      expected =
        [ [ "rs11240767", "718814", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1],
          [ "rs2185539",  "556738", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1],
          [ "rs3094315",  "742429", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1],
          [ "rs4477212",  "72017",  "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1],
          [ "rs6681105",  "581938", "1", {}, {"A"=>0, "T"=>0, "G"=>0, "C"=>0}, 0, 1] ]

      assert_equal expected, snp_data

      # UserSnp
      user_snps = UserSnp.all
      user_snp_genotypes = user_snps.map(&:local_genotype)
      expected_genotypes = %w[ AA CC TT CC TT ]
      assert_equal expected_genotypes, user_snp_genotypes
      user_snps.each do |s|
        assert_equal @genotype_decodeme.id, s.genotype_id
        assert_equal @genotype_decodeme.user.id, s.user_id
        assert Snp.pluck(:name).include?(s.snp_name)
      end
    end

    should "delete deCODEme data" do
      DeleteGenotype.new.perform(@genotype_decodeme)

      expected = 0
      number_of_snps = Snp.all.count

      assert_equal expected, number_of_snps
    end


  end
end