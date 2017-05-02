# DS_helper
A collection of scripts for streamlining DS imaging in my org.

Borrowed largely from the [Amsys first boot scripts](https://github.com/amsysuk/public_scripts/blob/master/first_boot/10.12_first_boot.sh) and [arunderwood's provisioning scripts](https://github.com/arunderwood/OSX-Provisioning).

You need to have the [CocoaDialog app](http://mstratman.github.io/cocoadialog/) parked in your DS scripts folder. I'm using version 3.0.0. Beta 7.

**Doesn't DeployStudio already do this?**
Yes, DS can setup users and host names and such based on data saved in it's database of serial numbers. I'd love to use this but my coworkers aren't really organized enough to manage the list and our fleet and inventory concerns aren't big enough to warrant me spending the time to do it for them. Asking for this info at image time generally gets everything we need done.

The component scripts work as follows:
#### AskForInfo.sh
It's purose is to ask the user for osme input and then passes that input to DS to be used later.

1. We're checking if the host is a VM or a real Mac and if it's a VM, asking to just used soem canned values. This is largely just for me since I do a lot of VM testing and this cuts some interaction out. Can be overriden by answering 'no' when asked. A real Mac host skips the prompt entirely. 
2. Checking if the host has an asset number saved in nvram. This is how we make asset tags accessable in software. If there's a tag already, we skip and continue, else we ask.
3. Ask for a department. The department dictates which initial munki manifest is used and also is used for setting the Watchamn Monitoring group so it's there when the machine is registered at wM install.
4. Asks for the user's long name. This is used for setting up the end users account and also in naming the machine. Maybe other things in the future.

#### WriteToDisk.sh
This script very simply takes the varibles passed to DS in the first script and, after the image has been restored, writes them to a file on the disk. This is nessessary because, currently, DS can't pass custom variables set in teh runtime to scripts run on first boot. Also, we separate this step from the first script so that the questions in the variables in the first script can be captured prior to imaging. The idea is that you could answer teh questions and just walk away, rather than waiting for the image to get applied first. 

#### delayedDoer.sh
This reads the file we wrote to the disk to get those vales and does these items:

1. Sets keyboard language and layout
2. Sets system language and region 
3. Supresses first run screens for iCloud, Siri and diagnotics.
4. Sets the timezone and network time server
5. Sets remote desktop settings
6. Enables SSH
7. Sets the Watchman Monitoring group and inital munki manifest
8. Creates a non-admin user with the name provided and a universal default password
9. Sets the sharing name and host name using the user's name
10. Sets the asset number in nvram if needed
