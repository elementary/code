from apport.hookutils import *
import os

def add_info(report, ui):

	attach_related_packages(report, ['scratch'])
	attach_conffiles(report, 'scratch')
	attach_mac_events(report)
       
	try:
		if not apport.packaging.is_distro_package(report['Package'].split()[0]):
			report['ThirdParty'] = 'True'
			report['CrashDB'] = 'scratch'
	except ValueError, e:
		return
