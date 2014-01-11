# -*- coding:utf-8 -*-
require 'gcalapi'

Plugin.create :mikutter_calendar do

  class CalendarTreeView < Gtk::TreeView
    COL_TIME  = 0
    COL_TITLE = 1

    def initialize
      super
      liststore = Gtk::ListStore.new(String, String)
      set_model(liststore)
      renderer = Gtk::CellRendererText.new
      col = Gtk::TreeViewColumn.new("時刻", renderer, :text => 0)
      append_column(col)
      col = Gtk::TreeViewColumn.new("予定", renderer, :text => 1)
      append_column(col)

      # Calendar
      load_schedule
    end

    def addline(time, title)
      iter = model.append
      iter[COL_TIME]  = time
      iter[COL_TITLE] = title
    end

    def clearlines()
      model.clear
    end

    def load_schedule
      feed = UserConfig[:m_cl_feed]
      priv = UserConfig[:m_cl_private]
      mail = UserConfig[:m_cl_mail]
      pass = UserConfig[:m_cl_pass]
      if mail && pass && feed then
        if priv then
          feed = feed.sub("public/basic", "private/full")
        end
        Thread.fork {
          begin
            srv = GoogleCalendar::Service.new(mail, pass)
            cal = GoogleCalendar::Calendar::new(srv, feed)
            @schedule = cal.events(:orderby => "starttime", "max-results" => 100)
          rescue => ee
            Message.new({
              :message => "再読み込みにに失敗しました\n#{ee}",
              :system => true
            })
          end
        }
      else
        @schedule = nil
      end
    end

    def get_schedule(y, m, d)
      clearlines
      selected = Time.new(y, m, d).localtime.strftime("%Y%m%d")
      if @schedule == nil then
        return
      end
      @schedule.each do |event|
        date = event.st.localtime.strftime("%Y%m%d")
        if date == selected then
          time = event.st.strftime("%H:%M")
          addline(time, event.title)
        end
      end
    end
  end


  tab(:mikutter_calendar, "カレンダー") do
    icon = File.expand_path(File.join(File.dirname(__FILE__), "calendar.png"))
    set_icon icon

    shrink
    btn = Gtk::Button.new('カレンダーを再読み込み')
    nativewidget Gtk::HBox.new(false, 0).closeup(btn)

    calendar = Gtk::Calendar.new
    nativewidget calendar

    expand
    view = CalendarTreeView.new
    nativewidget view
    view.get_schedule(Time.now.year, Time.now.month, Time.now.day)

    btn.signal_connect('clicked'){
      view.clearlines
      view.load_schedule
      if calendar.day then
        view.get_schedule(calendar.year, calendar.month + 1, calendar.day)
      end
    }
    calendar.signal_connect("day-selected") {
      if calendar.day then
        view.get_schedule(calendar.year, calendar.month + 1, calendar.day)
      end
    }

  end


  settings "カレンダー" do
    input("カレンダーのXMLのアドレス",:m_cl_feed)
    boolean("このカレンダーは一般公開ではない", :m_cl_private)
      settings "認証情報" do
        input("Googleアカウント",:m_cl_mail)
        input("パスワード",:m_cl_pass)
      end
  end
    
end
