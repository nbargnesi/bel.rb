# vim: ts=2 sw=2:
$: << File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'lib')
require 'bel'
require 'uuid'

BEL::Extension.load_extension %s(rdf/rdf)

include BEL::Language
include BEL::Namespace
include BEL::Model

describe 'RDF functionality of BEL language objects' do

  before(:all) do
    begin
      BEL::Extension.load_extension('rdf/rdf')
    rescue LoadError => e
      raise
    end
  end

  describe NamespaceDefinition do

    it "provides a URI based on namespace name" do
      stable_prefix = 'http://www.openbel.org/bel/namespace/'
      expect(HGNC.to_uri).to eq(stable_prefix + 'hgnc-human-genes')
    end
  end

  describe Parameter do

    it "provides a URI consistent with Namespace URI" do
      value = 'AKT1'
      expect(
        Parameter.new(HGNC, value, 'GRP').to_uri
      ).to eq(
        HGNC.to_rdf_vocabulary[value]
      )
    end

    it "provides RDF statements for concept types based on encoding" do
      triples = Parameter.new(HGNC, 'AKT1', 'GRP').to_rdf
      expect(triples.size).to eq(4)
      expect(
        triples.count { |x|
          x.object.uri? and x.object.value == BEL::RDF::BELV.AbundanceConcept
        }).to eq(1)
      expect(
        triples.count { |x|
          x.object.uri? and x.object.value == BEL::RDF::BELV.GeneConcept
        }).to eq(1)
      expect(
        triples.count { |x|
          x.object.uri? and x.object.value == BEL::RDF::BELV.RNAConcept
        }).to eq(1)
      expect(
        triples.count { |x|
          x.object.uri? and x.object.value == BEL::RDF::BELV.ProteinConcept
        }).to eq(1)
    end

    it "URL-encodes UTF-8 concepts" do
      uri = Parameter.new(CHEBI, '5α-androst-16-en-3-one').to_uri
      expect(uri.to_s).to include("%CE%B1")
    end
  end

  describe Term do

    it "provides RDF statements for Term instances" do
      term = p(Parameter.new(HGNC, 'AKT1', 'GRP'))

      (term_uri, rdf_statements) = term.to_rdf
      expect(term_uri).to eq(term.to_uri)
      expect(rdf_statements.size).to eq(4)
      expect(
        rdf_statements.include? [term.to_uri, BEL::RDF::RDF.type, BEL::RDF::BELV.Term]
      ).to be(true)
      expect(
        rdf_statements.include? [term.to_uri, BEL::RDF::RDF.type, term.rdf_type]
      ).to be(true)
      expect(
        rdf_statements.include? [term.to_uri, BEL::RDF::RDFS.label, term.to_s]
      ).to be(true)
      expect(
        rdf_statements.include? [term.to_uri, BEL::RDF::BELV.hasConcept, term.arguments[0].to_uri]
      ).to be(true)
    end

    it "forces term labels as UTF-8" do
      (_, rdf_statements) = a(Parameter.new(CHEBI, '5α-androst-16-en-3-one')).to_rdf
      _, _, label_literal = rdf_statements.find { |stmt|
        stmt[1] == BEL::RDF::RDFS.label
      }

      expect(label_literal.encoding).to eql(Encoding::UTF_8)
      expect(label_literal).to          eql(%Q{abundance(CHEBI:"5α-androst-16-en-3-one")})
    end
  end

  describe Statement do

    it "provides RDF statements for Statement instances" do
      statement = tscript(p(Parameter.new(HGNC, 'AKT1', 'GRP'))).increases bp(Parameter.new(GOBP, 'apoptotic process', 'B'))

      (uri, rdf_statements) = statement.to_rdf
      expect(uri).to eq(statement.to_uri)
      expect(rdf_statements.size).to eq(21)
    end

    it "reference a single Evidence identified by UUID blank node" do
      statement = kin(p(Parameter.new(SFAM, 'PRKC Family'))).increases cat(p(Parameter.new(SFAM, 'PLD Family')))
      (_, rdf_statements) = statement.to_rdf

      type_evidence_statements = rdf_statements.find_all { |stmt|
        stmt[1] == BEL::RDF::RDF.type and stmt[2] == BEL::RDF::BELV.Evidence
      }
      expect(type_evidence_statements.size).to eq(1)

      evidence_resource = type_evidence_statements.first[0]
      expect(evidence_resource).to be_a(BEL::RDF::RDF::Node)

      evidence_resource_identifier = evidence_resource.to_s.gsub(/^_:/, '')
      expect(UUID.validate(evidence_resource_identifier)).to be(true)
    end

    it "forces statement labels as UTF-8" do
      (_, rdf_statements) =
        (a(Parameter.new(CHEBI, '5α-androst-16-en-3-one')).association a(Parameter.new(CHEBI, 'luteolin 7-O-β-D-glucosiduronate'))).to_rdf
      _, _, label_literal = rdf_statements.select { |stmt|
        stmt[1] == BEL::RDF::RDFS.label
      }.last

      expect(label_literal.encoding).to eql(Encoding::UTF_8)
      expect(label_literal).to          eql(%Q{abundance(CHEBI:"5α-androst-16-en-3-one") association abundance(CHEBI:"luteolin 7-O-β-D-glucosiduronate")})
    end

    it "forces evidence text as UTF-8" do
      EVIDENCE_TEST = '''
        SET Evidence = "Contains UTF-8 ... 84±3 55±7% α O-β-D γ κ"
        a(SCHEM:Sorbitol) -> kin(p(RGD:Mapk8))
        SET Evidence = "Plain text ASCII."
        a(SCHEM:"Prostaglandin F1") -| bp(MESHPP:Apoptosis)
      '''.gsub(%r{^\s*}, '')

      BEL::Script.parse(EVIDENCE_TEST).select { |obj|
        obj.is_a? Statement
      }.each do |stmt|
        expect(stmt.annotations).to include('Evidence')
        evidence = stmt.annotations['Evidence']
        expect(evidence.value.encoding).to eql(Encoding::UTF_8)
      end
    end
  end
end
