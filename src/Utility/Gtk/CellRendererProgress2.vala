	public class CellRendererProgress2 : Gtk.CellRendererProgress{
		public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
			if (text == "--")
				return;

			int diff = (int) ((cell_area.height - height)/2);

			// Apply the new height into the bar, and center vertically:
			Gdk.Rectangle new_area = Gdk.Rectangle() ;
			new_area.x = cell_area.x;
			new_area.y = cell_area.y + diff;
			new_area.width = width - 5;
			new_area.height = height;

			base.render(cr, widget, background_area, new_area, flags);
		}
	}

