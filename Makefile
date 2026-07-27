INVENTORY = inventory.ini
PLAYBOOK  = playbook.yml
VAULT     = group_vars/all/vault.yml

.PHONY: install ping setup deploy vault-edit vault-view

install:
	ansible-galaxy install -r requirements.yml

ping:
	ansible all -i $(INVENTORY) -m ping

setup: install
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --tags setup

deploy:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --tags deploy

vault-edit:
	ansible-vault edit $(VAULT)

vault-view:
	ansible-vault view $(VAULT)
