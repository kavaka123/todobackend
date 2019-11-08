#Project variables
PROJECT_NAME ?= todobackend
ORG_NAME ?= avantaditya
REPO_NAME ?= todobackend
DOCKER_REGISTRY ?= docker.io


#Filenames
DEV_COMPOSE_FILE := docker/dev/docker-compose-v2.yml
REL_COMPOSE_FILE := docker/release/docker-compose-v2.yml


#Docker compose project names
REL_PROJECT := $(PROJECT_NAME)$(BUILD_ID)
DEV_PROJECT := $(REL_PROJECT)dev

#Build tag expression
BUILD_TAG_EXPRESSION ?= date -u +%Y%m%d%H%M%S

#Execute shell expression
BUILD_EXPRESSION := $(shell $(BUILD_TAG_EXPRESSION))

#Build tag - defaults to build_expression if not defined in env variables
BUILD_TAG ?= $(BUILD_EXPRESSION)


#App service name which is the name of service directive for app release environment
APP_SERVICE_NAME := app

#Check and Inspect variables for checking exit status of docker-compose
INSPECT := $$(docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c '\
  if [[ $(INSPECT) -ne 0 ]];then \
      exit $(INSPECT); fi' VALUE


#DOCKER_REGISTRY_AUTH is for registries other than docker hub, if there is any env variable with this name, it'll be considered
#default is empty expression which is for docker hub
DOCKER_REGISTRY_AUTH ?= 


.PHONY: test build release clean tag buildtag login logout publish

test:
	$(INFO) "Creating cache external volume as docker-compose will not create nor destroy external volumes.."
	@docker volume create --name cache
	$(INFO) "Pulling latest images for services using image directive.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) pull
	$(INFO) "Building images for services using build directive.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build --pull test
	$(INFO) "Ensuring database is ready.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) run --rm agent
	$(INFO) "Running unit and integration tests.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up test
	$(INFO) "Copying unit/integration test reports and coverage reports to client machibe reports folder"
	@docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q test):/reports/. reports
	$(CHECK) $(DEV_PROJECT) $(DEV_COMPOSE_FILE) test	
	$(INFO) "Tests completed.."

build:
	$(INFO) "Creating builder image that was used in dev/test stage.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) build builder
	$(INFO) "Building application artifacts.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) up builder
	$(CHECK) $(DEV_PROJECT) $(DEV_COMPOSE_FILE) builder
	$(INFO) "Copying build artifacts to target folder on client machine target folder"
	@docker cp $$(docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) ps -q builder):/wheelhouse/. target
	$(INFO) "Build complete.."

release:
	$(INFO) "Pulling images for specs service.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) pull test
	$(INFO) "Building images for remaining services.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build app
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) build --pull nginx
	$(INFO) "Ensuring database is ready.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm agent
	$(INFO) "Collecting static files.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py collectstatic --no-input
	$(INFO) "Running database migrations.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) run --rm app manage.py migrate --no-input
	$(INFO) "Running acceptance tests.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) up test
	$(INFO) "Copying acceptance test reports from containers to client machine reports folder"
	@docker cp $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q test):/reports/. reports
	$(CHECK) $(REL_PROJECT) $(REL_COMPOSE_FILE) test	
	$(INFO) "Accepatance tests completed.."

clean:
	$(INFO) "Destroying development environment.."
	@docker-compose -p $(DEV_PROJECT) -f $(DEV_COMPOSE_FILE) down -v
	$(INFO) "Destroying release environment.."
	@docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) down -v
	$(INFO) "Removing dangling images.."
	@docker images -q -f dangling=true -f label=application=$(REPO_NAME) -q | xargs -I ARGS docker rmi -f ARGS
	$(INFO) "Clean complete.."

tag:
	$(INFO) "Tagging release image with tags $(TAG_ARGS).."
	@$(foreach tag, $(TAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)
	$(INFO) "Tagging complete.."	


buildtag:
	$(INFO) "Tagging release image with suffix $(BUILD_TAG) and tags $(BUILD_TAG_ARGS).."
	@$(foreach tag, $(BUILD_TAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag).$(BUILD_TAG);)
	$(INFO) "Tagging complete.."	


login:
	$(INFO) "Logging into docker registry $(DOCKER_REGISTRY).."
	@docker login -u $$DOCKER_USER -p $$DOCKER_PASSWORD $(DOCKER_REGISTRY_AUTH)
	$(INFO) "Logged into docker registry $(DOCKER_REGISTRY).."

logout:
	$(INFO) "Logging out of docker registry $(DOCKER_REGISTRY).."
	@docker logout
	$(INFO) "Logged out of docker registry $(DOCKER_REGISTRY).."

publish:
	$(INFO) "Publishing image $(IMAGE_ID) to $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME).."
	@$(foreach tag, $(shell echo $(REPO_EXPR)), docker push $(tag);)
	$(INFO) "Publishing completed.."


#Cosmentics
YELLOW := "\e[1;33m"
NC := "\e[0m"

#Shell functions
INFO := @bash -c '\
  printf $(YELLOW); \
  echo "==> $$1"; \
  printf $(NC)' VALUE


#Get container id of app service container
APP_CONTAINER_ID := $$(docker-compose -p $(REL_PROJECT) -f $(REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))

#Get Image id of application service
IMAGE_ID := $$(docker inspect -f '{{ .Image }}' $(APP_CONTAINER_ID))


#REPO_FILTER is a regex to match ORG_NAME/REPO_NAME for docker hub images and DOCKER_REGISTRY/ORG_NAME/REPO_NAME for private registries
ifeq ($(DOCKER_REGISTRY), docker.io)
  REPO_FILTER := $(ORG_NAME)/$(REPO_NAME)
else
  REPO_FILTER := $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)
endif     

#get all repository tags when searched with IMAGE_ID
REPO_EXPR := $$(docker inspect -f '{{range .RepoTags}}{{.}} {{end}}' $(IMAGE_ID) | xargs -n1 | grep "$(REPO_FILTER)" | xargs)

#Extract BUILD_TAG_ARGS
ifeq (buildtag, $(firstword $(MAKECMDGOALS)))
  BUILD_TAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifeq ($(BUILD_TAG_ARGS),)
  	$(error you must specify a tag)
  endif
  $(eval $(BUILD_TAG_ARGS):;@:)
endif


#Extract TAG_ARGS
ifeq (tag, $(firstword $(MAKECMDGOALS)))
  TAG_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifeq ($(TAG_ARGS),)
	$(error you must specify a tag)
  endif
  $(eval $(TAG_ARGS):;@:)
endif

