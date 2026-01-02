# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:parent).class_name("Category").optional }
    it { is_expected.to have_many(:children).class_name("Category").with_foreign_key(:parent_id).dependent(:destroy) }
    it { is_expected.to have_many(:form_definitions).dependent(:nullify) }
    it { is_expected.to have_many(:workflows).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:category) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug) }

    it "validates presence of slug (after normalization)" do
      category = build(:category, name: "Test", slug: "")
      category.valid?
      expect(category.slug).not_to be_blank

      category.name = ""
      category.slug = ""
      expect(category).not_to be_valid
      expect(category.errors[:slug]).to include("can't be blank")
    end

    it "allows 2 levels of categories" do
      parent = create(:category)
      child = build(:category, parent: parent)
      expect(child).to be_valid
    end

    it "does not allow 3 levels of categories" do
      root = create(:category)
      parent = create(:category, parent: root)
      child = build(:category, parent: parent)

      expect(child).not_to be_valid
      expect(child.errors[:parent]).to include("only 2 levels allowed")
    end
  end

  describe "callbacks" do
    it "generates a slug from name if slug is blank" do
      category = Category.new(name: "Test Category Name")
      category.valid?
      expect(category.slug).to eq("test-category-name")
    end

    it "does not overwrite existing slug" do
      category = Category.new(name: "Test Category", slug: "custom-slug")
      category.valid?
      expect(category.slug).to eq("custom-slug")
    end
  end

  describe "scopes" do
    let!(:root) { create(:category, parent: nil, position: 2, name: "B Root") }
    let!(:child) { create(:category, parent: root, position: 1, name: "A Child") }
    let!(:inactive) { create(:category, active: false) }

    describe ".roots" do
      it "returns categories without a parent" do
        expect(Category.roots).to include(root)
        expect(Category.roots).not_to include(child)
      end
    end

    describe ".active" do
      it "returns only active categories" do
        expect(Category.active).to include(root, child)
        expect(Category.active).not_to include(inactive)
      end
    end

    describe ".ordered" do
      it "orders by position and then name" do
        Category.delete_all
        c1 = create(:category, position: 2, name: "B")
        c2 = create(:category, position: 1, name: "Z")
        c3 = create(:category, position: 1, name: "A")

        expect(Category.ordered.to_a).to eq([ c3, c2, c1 ])
      end
    end
  end

  describe "instance methods" do
    let(:root) { create(:category, name: "Root", slug: "root") }
    let(:child) { create(:category, name: "Child", slug: "child", parent: root) }

    describe "#root?" do
      it "returns true if parent_id is nil" do
        expect(root.root?).to be true
        expect(child.root?).to be false
      end
    end

    describe "#child?" do
      it "returns true if parent_id is present" do
        expect(root.child?).to be false
        expect(child.child?).to be true
      end
    end

    describe "#full_path" do
      it "returns slug for root categories" do
        expect(root.full_path).to eq("root")
      end

      it "returns parent/slug for child categories" do
        expect(child.full_path).to eq("root/child")
      end
    end

    describe "#display_name" do
      it "returns name for root categories" do
        expect(root.display_name).to eq("Root")
      end

      it "returns parent > name for child categories" do
        expect(child.display_name).to eq("Root > Child")
      end
    end
  end
end
