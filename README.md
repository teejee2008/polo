## Polo File Manager

Polo is a modern, light-weight file manager for Linux with support for multiple panes, tabs, archive browsing/creation/extraction, and much more.

**Features:**
* **Multiple panes** - Single-pane, dual-pane (vertical or horizontal split) and quad-pane layouts.

* **Multiple views** - List view, Icon view, Tiled view and Media view.

* **Device Manager** - Devices can be mounted and unmounted with a single click. Supports locking and unlocking LUKS encrypted devices.

  [![](https://4.bp.blogspot.com/-KSRmPybuvpY/WOm00ZHbLaI/AAAAAAAAGO0/DretRJ5jnB0PR4zVRu40AQv3NHui76ArACLcB/s320/polo_device_dropdown.png)](https://4.bp.blogspot.com/-KSRmPybuvpY/WOm00ZHbLaI/AAAAAAAAGO0/DretRJ5jnB0PR4zVRu40AQv3NHui76ArACLcB/s1600/polo_device_dropdown.png)

* **Archive Support** (using p7zip)

  * Archives can be browsed as normal folders with support for encrypted and split archives.
  * Archives can be created in multiple formats by selecting files and using the _Compress_ option in the right-click menu. Provides options for all compression settings, encryption and splitting.

    [![](https://3.bp.blogspot.com/-IS1yfrAgVfI/WQ1jQBOOE-I/AAAAAAAAGfc/a3c9wGnVAx4IFHrw5oXFKuF_JzVsOJMSACLcB/s320/polo_compress.png)](https://3.bp.blogspot.com/-IS1yfrAgVfI/WQ1jQBOOE-I/AAAAAAAAGfc/a3c9wGnVAx4IFHrw5oXFKuF_JzVsOJMSACLcB/s1600/polo_compress.png)  [![](https://2.bp.blogspot.com/-s4qwOZ7W3tE/WQ1jP1u-ZfI/AAAAAAAAGfY/J5m6mpYrEU09N2erLx5zb6L3fomF7eH4gCLcB/s320/polo_compress_expanded.png)](https://2.bp.blogspot.com/-s4qwOZ7W3tE/WQ1jP1u-ZfI/AAAAAAAAGfY/J5m6mpYrEU09N2erLx5zb6L3fomF7eH4gCLcB/s1600/polo_compress_expanded.png)

  * Displays detailed progress during compression and extraction. Archive operations can be paused and resumed.

      [![](https://4.bp.blogspot.com/-8nrEdE3U9Pc/WQ1k9S9HytI/AAAAAAAAGfo/izFm14Gu7GEhQbIrnTMFGd0XfEdkKWtbACLcB/s460/polo_compress_progress.png)](https://4.bp.blogspot.com/-8nrEdE3U9Pc/WQ1k9S9HytI/AAAAAAAAGfo/izFm14Gu7GEhQbIrnTMFGd0XfEdkKWtbACLcB/s1600/polo_compress_progress.png)



## Screenshots

[![](https://2.bp.blogspot.com/-N8kfKyg05gc/WSFeSxoNlHI/AAAAAAAAGv4/4624nEvjAYU7WB5VL-6CMIhfX_7sjJZcACLcB/s1600/polo_layout_classic_icons.png)](https://2.bp.blogspot.com/-N8kfKyg05gc/WSFeSxoNlHI/AAAAAAAAGv4/4624nEvjAYU7WB5VL-6CMIhfX_7sjJZcACLcB/s1600/polo_layout_classic_icons.png)

[![](https://2.bp.blogspot.com/-ztn3NTFgZ7g/WSFeSyKB_CI/AAAAAAAAGv0/KqTj5Bd5VKkpqOED08G1fMtMznR980-FQCLcB/s1600/polo_layout_classic_list.png)](https://2.bp.blogspot.com/-ztn3NTFgZ7g/WSFeSyKB_CI/AAAAAAAAGv0/KqTj5Bd5VKkpqOED08G1fMtMznR980-FQCLcB/s1600/polo_layout_classic_list.png)

![](https://1.bp.blogspot.com/-i0M8VMXGW2E/WSFeS7_XqBI/AAAAAAAAGvw/hWYkNIpn1w8IHvRqorNgjwcopfL6ZofvgCLcB/s1600/polo_layout_commander_icons.png)](https://1.bp.blogspot.com/-i0M8VMXGW2E/WSFeS7_XqBI/AAAAAAAAGvw/hWYkNIpn1w8IHvRqorNgjwcopfL6ZofvgCLcB/s1600/polo_layout_commander_icons.png)

[![](https://4.bp.blogspot.com/-SoXr3INsUYo/WSFeTl19N_I/AAAAAAAAGv8/29ZnneUnWtYZhI-t3rQCx2z_n1JcjLtJQCLcB/s1600/polo_layout_commander_list.png)](https://4.bp.blogspot.com/-SoXr3INsUYo/WSFeTl19N_I/AAAAAAAAGv8/29ZnneUnWtYZhI-t3rQCx2z_n1JcjLtJQCLcB/s1600/polo_layout_commander_list.png)

### Installation

**Ubuntu-based Distributions (Ubuntu, Linux Mint, etc)**

Packages are available in the Launchpad PPA for supported Ubuntu releases.
Run the following commands in a terminal window:  

```sh
sudo apt-add-repository -y ppa:teejee2008/ppa
sudo apt-get update
sudo apt-get install polo-file-manager
```

Installers are available on the [Releases](https://github.com/teejee2008/polo/releases) page for older Ubuntu releases which have reached end-of-life.

**Other Linux Distributions**

Installers are available on the [Releases](https://github.com/teejee2008/polo/releases) page.  
Run the following commands in a terminal window: 
```sh
sudo sh polo*amd64.run # 64-bit
sudo sh polo*i386.run  # 32-bit
```


### Donate

Users who donate get added to the beta mailing list, and would be the first to receive new features and development releases. Beta builds are released every 2 weeks, and public versions are released once a month.

**PayPal** ~ If you find this application useful and wish to say thanks, you can buy me a coffee by making a one-time donation with Paypal. 

[![](https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg)](https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Polo%20Donation)  

**Patreon** ~ You can also sign up as a sponsor on Patreon.com. As a patron you will get access to beta releases of new applications that I'm working on. You will also get news and updates about new features that are not published elsewhere.

[![](https://2.bp.blogspot.com/-DNeWEUF2INM/WINUBAXAKUI/AAAAAAAAFmw/fTckfRrryy88pLyQGk5lJV0F0ESXeKrXwCLcB/s200/patreon.png)](https://www.patreon.com/bePatron?u=3059450)

**Bitcoin** ~ You can send bitcoins at this address or by scanning the QR code below:

```1Js5vfgmwKew4byF9unWacwAjBQVvZ3Fev```

![](https://4.bp.blogspot.com/-9hMyCacf0nc/WQ1p3dcdtwI/AAAAAAAAGgA/WC-4gbGFl7skTjNRZbl99EBsXeYfZDqpgCLcB/s1600/polo.png)