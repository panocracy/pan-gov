class Petition < ActiveRecord::Base
	has_many :comments, :as => :commentable, :dependent => :destroy
	acts_as_taggable
	acts_as_votable
	include PublicActivity::Model
  	tracked except: :update, owner: Proc.new{ |controller, model| controller.current_user||nil }

 	searchable do
	    text :name, :content
	    # text :comments do
	    #   comments.map { |comment| comment.content }
	    # end
	    time    :created_at
	    time    :expires_at

	    # string  :sort_title do
	    #   title.downcase.gsub(/^(an?|the)/, '')
	    # end
	end

	def required_votes
		@votes = (User.all.size / 100) * 5
		unless @votes < 1 
			return @votes
		else 
			return 10
		end
	end

	def self.support_spread
	    @c1 = 0
	    @c2 = 0
	    @c3 = 0
	    Petition.all.each do |petition|
	      @votes_per = ((petition.votes_for.size/petition.required_votes) * 100)
	      case @votes_per
	        when 0..30
	         @c1+=1
	        when 30..70
	         @c2+=1
	        when 70..100
	         @c3+=1
	      end
	    end
	    return [@c1,@c2,@c3]
	end

	filterrific(
	  default_filter_params: { sorted_by: 'created_at_desc' },
	  available_filters: [
	    :sorted_by,
	    :search_query,
	    :tagged_with,
	    :with_created_at_gte
	  ]
	)

	scope :recent_day, -> { where("created_at > ?", Time.now-1.days) }
	scope :recent_week, -> { where("created_at > ?", Time.now-7.days) }
	scope :recent_month, -> { where("created_at > ?", Time.now-1.month) }
	scope :recent_year, -> { where("created_at > ?", Time.now-1.years) }

	scope :search_query, lambda { |query|
	  # Searches the students table on the 'first_name' and 'last_name' columns.
	  # Matches using LIKE, automatically appends '%' to each term.
	  # LIKE is case INsensitive with MySQL, however it is case
	  # sensitive with PostGreSQL. To make it work in both worlds,
	  # we downcase everything.
	  return nil  if query.blank?

	  # condition query, parse into individual keywords
	  terms = query.downcase.split(/\s+/)

	  # replace "*" with "%" for wildcard searches,
	  # append '%', remove duplicate '%'s
	  terms = terms.map { |e|
	    (e.gsub('*', '%') + '%').gsub(/%+/, '%')
	  }
	  # configure number of OR conditions for provision
	  # of interpolation arguments. Adjust this if you
	  # change the number of OR conditions.
	  num_or_conds = 1
	  where(
	    terms.map { |term|
	      "(LOWER(petitions.name) LIKE ?)"
	    }.join(' AND '),
	    *terms.map { |e| [e] * num_or_conds }.flatten
	  )
	}
	  scope :with_created_at_gte, lambda { |ref_date|
	  	where('petitions.created_at >= ?', reference_time)
	  }

	  scope :sorted_by, lambda { |sort_option|
	  # extract the sort direction from the param value.
	  direction = (sort_option =~ /desc$/) ? 'desc' : 'asc'
	  case sort_option.to_s
	  when /^created_at_/
	    # Simple sort on the created_at column.
	    # Make sure to include the table name to avoid ambiguous column names.
	    # Joining on other tables is quite common in Filterrific, and almost
	    # every ActiveRecord table has a 'created_at' column.
	    order("petitions.created_at #{ direction }")
	  when /^name_/
	    # Simple sort on the name colums
	    order("LOWER(petitions.name) #{ direction }")
	  else
	    raise(ArgumentError, "Invalid sort option: #{ sort_option.inspect }")
	  end
	}

	def self.options_for_sorted_by
    [
      ['Name (a-z)', 'name_asc'],
      ['Creation date (newest first)', 'created_at_desc'],
      ['Creation date (oldest first)', 'created_at_asc'],
    ]
	end

end
