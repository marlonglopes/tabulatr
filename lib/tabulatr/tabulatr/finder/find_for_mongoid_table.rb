#--
# Copyright (c) 2010-2011 Peter Horn, Provideal GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# These are extensions for use from ActionController instances
# In a seperate class call only for clearity
module Tabulatr::Finder

  # ----------------------------------------------------------------
  # Called if SomeMongoidDocument::find_for_table(params) is called
  #
  def self.find_for_mongoid_table(klaz, params, opts={})
    # firstly, get the conditions from the filters
    cname = class_to_param(klaz)
    filter_param = (params["#{cname}#{TABLE_FORM_OPTIONS[:filter_postfix]}"] || {})
    conditions = filter_param.inject({}) do |c, t|
      n, v = t
      nc = c
      # FIXME n = name_escaping(n)
      raise "SECURITY violation, field name is '#{n}'" unless /^[\d\w]+$/.match n
      if v.class == String
        if v.present?
          nc[n.to_sym] = v
        end
      elsif v.is_a?(Hash)
        if v[:like]
          if v[:like].present?
            nc[n.to_sym] = Regexp.new("#{v[:like]}")
          end
        else
          nc[n.to_sym.gte] = "#{v[:from]}" if v[:from].present?
          nc[n.to_sym.lte] = "#{v[:to]}" if v[:to].present?
        end
      else
        raise "Wrong filter type: #{v.class}"
      end
      nc
    end

    # secondly, find the order_by stuff
    # FIXME: Implement me! PLEEEZE!
    sortparam = params["#{cname}#{TABLE_FORM_OPTIONS[:sort_postfix]}"]
    if sortparam
      if sortparam[:_resort]
        order_by = sortparam[:_resort].first.first
        order_direction = sortparam[:_resort].first.last.first.first
      else
        order_by = sortparam.first.first
        order_direction = sortparam.first.last.first.first
      end
      raise "SECURITY violation, sort field name is '#{n}'" unless /^[\w]+$/.match order_direction
      raise "SECURITY violation, sort field name is '#{n}'" unless /^[\d\w]+$/.match order_by
      order = [order_by, order_direction]
    else
      order = nil
    end

    # thirdly, get the pagination data
    paginate_options = PAGINATE_OPTIONS.merge(opts).
      merge(params["#{cname}#{TABLE_FORM_OPTIONS[:pagination_postfix]}"] || {})
    page = paginate_options[:page].to_i
    page += 1 if paginate_options[:page_right]
    page -= 1 if paginate_options[:page_left]
    pagesize = paginate_options[:pagesize].to_f
    c = klaz.count :conditions => conditions
    pages = (c/pagesize).ceil
    page = [1, [page, pages].min].max

    # Now, actually find the stuff
    found = klaz.find(:conditions => conditions)
    found = found.order_by([order]) if order
    found = found.paginate(:page => page, :per_page => pagesize)

    # finally, inject methods to retrieve the current 'settings'
    found.define_singleton_method(fio[:filters]) do filter_param end
    found.define_singleton_method(fio[:classname]) do cname end
    found.define_singleton_method(fio[:pagination]) do
      {:page => page, :pagesize => pagesize, :count => c, :pages => pages,
        :pagesizes => paginate_options[:pagesizes]}
    end
    found.define_singleton_method(fio[:sorting]) do
      order ? { :by => order_by, :direction => order_direction } : nil
    end
    checked_param = params["#{cname}#{TABLE_FORM_OPTIONS[:checked_postfix]}"]
    checked_ids = checked_param[:checked].split(TABLE_FORM_OPTIONS[:checked_separator])
    new_ids = checked_param[:current_page] || []
    selected_ids = checked_ids + new_ids
    ids = found.map { |r| r.id.to_s }
    checked_ids = selected_ids - ids
    found.define_singleton_method(fio[:checked]) do
      { :selected => selected_ids,
        :checked_ids => checked_ids.join(TABLE_FORM_OPTIONS[:checked_separator]) }
    end
    found
  end

end