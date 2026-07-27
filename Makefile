INVENTORY = inventory.ini
PLAYBOOK  = playbook.yml

.PHONY: install ping setup deploy

install:
	ansible-galaxy install -r requirements.yml

ping:
	ansible all -i $(INVENTORY) -m ping

setup: install
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --tags setup

deploy:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --tags deploy
