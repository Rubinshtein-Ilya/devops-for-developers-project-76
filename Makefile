INVENTORY = inventory.ini
PLAYBOOK  = playbook.yml

.PHONY: install ping setup

install:
	ansible-galaxy install -r requirements.yml

ping:
	ansible all -i $(INVENTORY) -m ping

setup: install
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK)
